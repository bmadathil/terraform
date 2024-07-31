import * as fs from "fs";
import * as path from "path";
import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";
import { Database, ExternalSecret } from "../interfaces";
import { createExternalSecret, retrieveCredentials } from "./functions";

interface Workload {
  name: string;
  host: string;
  db: Database;
  replicas: number;  
  realmImports: string[];
  adminCredentials: ExternalSecret;
  clientSecrets: ExternalSecret;
}

const KEYCLOAK = "keycloak";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === KEYCLOAK
    );

    if (workload) {

      const configMap = new k8s.core.v1.ConfigMap(
        `${namespace}-configmap`,
        {
          metadata: {
            name: `${KEYCLOAK}-configmap`,
            namespace,
          },
          data: {
            KC_DB: "postgres",// postgres engine
            KC_DB_SCHEMA: KEYCLOAK,
            KC_HOSTNAME_DEBUG: "true",
            KC_HTTP_ENABLED: "true",
            KC_METRICS_ENABLED: "true",
            KC_PROXY: "edge",
          },
        },
        { provider: clusterK8sProvider }
      );

      const name = workload.clientSecrets.name;

      new k8s.apiextensions.CustomResource(
        `${namespace}-${name}-external-secrets`,
        {
          apiVersion: "external-secrets.io/v1beta1",
          kind: "ExternalSecret",
          metadata: {
            name: `${name}-external-secrets`,
            namespace,
          },
          spec: {
            refreshInterval: "1h",
            secretStoreRef: {
              name: "external-secrets-store",
              kind: "SecretStore",
            },
            target: {
              name,
              creationPolicy: "Owner",
            },
            data: workload.clientSecrets.data,
          },
        },
        { provider: clusterK8sProvider }
      );

      const clientSecret = workload.clientSecrets.data.find(
        item => item.secretKey === "client-secret"
      );

      let awsSecret = await aws.secretsmanager.getSecretVersion({
        secretId: clientSecret?.remoteRef.key || "",
      });
  
      let secretData = JSON.parse(awsSecret.secretString);

      const fileConfigs: string[] = [];
      const dirPath = path.resolve(__dirname, `realms`);

      workload.realmImports.forEach(file => {
        let fileContents = fs.readFileSync(`${dirPath}/${file}`, "utf8");
        const config = JSON.parse(fileContents);
        const secretKey = config.clients[0].secret;
        fileContents = fileContents.replace(
          `"secret": "${secretKey}"`,
          `"secret": "${secretData[secretKey]}"`,
        );
        fileConfigs.push(
          `"${file}": ${JSON.stringify(fileContents)}`
        );
      });
      
      const data = JSON.parse(`{ ${fileConfigs.join(',')} }`);

      const realmsConfigMap = new k8s.core.v1.ConfigMap(
        `${namespace}-realms-configmap`,
        {
          metadata: {
            name: `${KEYCLOAK}-realms-configmap`,
            namespace,
          },
          data,
        },
        { provider: clusterK8sProvider }
      );

      const adminSecret = await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );

      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials, true
      );
      
      new k8s.helm.v3.Release(
        `${namespace}-release`,
        {
          name: KEYCLOAK,
          namespace,
          chart: "./keycloak",
          values: {
            replicaCount: workload.replicas,
            auth: {
              adminUser: adminCredentials.username,
              existingSecret: workload.adminCredentials.name,
              passwordSecretKey: adminCredentials.passwordSecretKey,
            },
            extraEnvVarsCM: configMap.metadata.name,
            extraStartupArgs: "--import-realm",
            extraVolumes: [
              {
                name: realmsConfigMap.metadata.name,
                configMap: {
                  name: realmsConfigMap.metadata.name,
                },
              },
            ],
            extraVolumeMounts: [
              {
                name: realmsConfigMap.metadata.name,
                mountPath: "/opt/bitnami/keycloak/data/import",
                readOnly: true,
              },
            ],
            postgresql: {
              enabled: !workload.db.external,
            },
            // THE FOLLOWING IS FOR EXTERNAL DATABASE & IS IGNORED IF postgres.enabled ABOVE IS TRUE
            externalDatabase: {
              port: workload.db.port,
              host: workload.db.host,
              database: workload.db.name,
              existingSecret: workload.db.secret.name,
              existingSecretUserKey: workload.db.secret.userKey,
              existingSecretPasswordKey: workload.db.secret.passwordKey,
            }
          },
        },
        {
          dependsOn: [configMap, adminSecret, realmsConfigMap],
          provider: clusterK8sProvider,
        }
      );

      new k8s.apiextensions.CustomResource(
        `${namespace}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: `${KEYCLOAK}-ingressroute`,
            namespace,
          },
          spec: {
            entryPoints: ["websecure"],
            routes: [
              {
                kind: "Rule",
                match: `Host(\`${workload.host}\`)`,
                services: [
                  {
                    name: KEYCLOAK,
                    namespace,
                    kind: "Service",
                    port: 80,
                  },
                ],
              },
            ],
            tls: {
              certResolver: "le",
            },
          },
        }
      );

    }

  });

}

execute();
