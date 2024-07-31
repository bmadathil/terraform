import * as cmd from "@pulumi/command";
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
  adminCredentials: ExternalSecret;
  jenkinsCredentials: ExternalSecret;
}

const SONARQUBE = "sonarqube";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;
    const key = `${namespace}-${SONARQUBE}`;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === SONARQUBE
    );

    if (workload) {

      const adminSecret = await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );

      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials, true
      );

      const sonarqubeUsername = adminCredentials.username;
      const sonarqubePassword = adminCredentials.password;

      const release = new k8s.helm.v3.Release(
        `${key}-release`,
        {
          name: SONARQUBE,
          namespace,
          chart: "./sonarqube",
          values: {
            replicaCount: workload.replicas,
            sonarqubeUsername,
            existingSecret: workload.adminCredentials.name,
            persistence: { enabled: true },
            service: {
              type: "ClusterIP",
              ports: {
                http: 9000,
              },
            },
            postgresql: {
              enabled: !workload.db.external,
            },
            externalDatabase: {
              port: workload.db.port,
              host: workload.db.host,
              user: workload.db.user,
              database: workload.db.name,
              existingSecret: workload.db.secret.name,
            }
          },
        },
        {
          dependsOn: [adminSecret],
          provider: clusterK8sProvider,
        }
      );

      new k8s.apiextensions.CustomResource(
        `${key}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: `${SONARQUBE}-ingressroute`,
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
                    name: SONARQUBE,
                    kind: "Service",
                    namespace,
                    port: 9000,
                  },
                ],
              },
            ],
            tls: {
              certResolver: "le",
            },
          },
        },
        { provider: clusterK8sProvider }
      );

      const jenkinsDns = `jenkins.${namespace}.svc.cluster.local:8080`;
      const sonarDns = `${SONARQUBE}.${namespace}.svc.cluster.local:9000`;

      new k8s.batch.v1.Job(
        `create-${key}-jenkins-webhook`,
        {
          metadata: {
            name: `create-${SONARQUBE}-jenkins-webhook`,
            namespace,
          },
          spec: {
            backoffLimit: 5,
            template: {
              spec: {
                containers: [
                  {
                    name: "curl-jq",
                    image: "softonic/curl-jq:3.18.3",
                    command: [
                      "curl", "-v",
                      "-u", `${sonarqubeUsername}:${sonarqubePassword}`,
                      "--data-urlencode", "name=Jenkins",
                      "--data-urlencode", `url=http://${jenkinsDns}/sonarqube-webhook/`,
                      `http://${sonarDns}/api/webhooks/create`,
                    ],
                  },
                ],
                restartPolicy: "Never",
              },
            },
          },
        },
        {
          dependsOn: [release],
          provider: clusterK8sProvider,
        }
      );

      const jenkinsSecret = await createExternalSecret(
        namespace, workload.jenkinsCredentials, clusterK8sProvider
      );

      const jenkinsCredentials = await retrieveCredentials(
        workload.jenkinsCredentials, true
      );

      const jenkinsUsername = jenkinsCredentials.username;
      const jenkinsPassword = jenkinsCredentials.password;

      const createJenkinsUser = new k8s.batch.v1.Job(
        `create-${key}-jenkins-user`,
        {
          metadata: {
            name: `create-${SONARQUBE}-jenkins-user`,
            namespace,
          },
          spec: {
            backoffLimit: 5,
            template: {
              spec: {
                containers: [
                  {
                    name: "curl-jq",
                    image: "softonic/curl-jq:3.18.3",
                    command: [
                      "curl", "-v",
                      "-u", `${sonarqubeUsername}:${sonarqubePassword}`,
                      "--data-urlencode", `login=${jenkinsUsername}`,
                      "--data-urlencode", `password=${jenkinsPassword}`,
                      "--data-urlencode", "name=Jenkins",
                      `http://${sonarDns}/api/users/create`,
                    ],
                  },
                ],
                restartPolicy: "Never",
              },
            },
          },
        },
        {
          dependsOn: [release, jenkinsSecret],
          provider: clusterK8sProvider,
          replaceOnChanges: ["*"],
          deleteBeforeReplace: true,
        }
      );

      const createJenkinsToken = new k8s.batch.v1.Job(
        `create-${key}-jenkins-token`,
        {
          metadata: {
            name: `create-${SONARQUBE}-jenkins-token`,
            namespace,
          },
          spec: {
            backoffLimit: 5,
            template: {
              spec: {
                containers: [
                  {
                    name: "curl-jq",
                    image: "softonic/curl-jq:3.18.3",
                    command: [
                      "sh", "-c",
                      `echo $(curl -s -u ${jenkinsUsername}:${jenkinsPassword} --data-urlencode name=jenkins-token http://${sonarDns}/api/user_tokens/generate | jq -r '.token')`,
                    ],
                  },
                ],
                restartPolicy: "Never",
              },
            },
          },
        },
        {
          dependsOn: [createJenkinsUser],
          provider: clusterK8sProvider,
          replaceOnChanges: ["*"],
          deleteBeforeReplace: true,
        }
      );

      const fetchJenkinsToken = new cmd.local.Command(
        `fetch-${key}-jenkins-token`,
        {
          create:
            `kubectl -n ${namespace} get pods --selector=job-name=create-${SONARQUBE}-jenkins-token -o jsonpath='{.items[0].metadata.name}' | xargs kubectl -n ${namespace} logs`,
        },
        { dependsOn: [createJenkinsToken] }
      );

      new k8s.core.v1.Secret(
        `${key}-jenkins-token-secret`,
        {
          metadata: {
            name: `${SONARQUBE}-jenkins-token`,
            namespace,
            annotations: {
              "jenkins.io/credentials-description":
              "Token used to access SonarQube within pipelines.",
            },
            labels: {
              "jenkins.io/credentials-type": "secretText",
            },
          },
          type: "Opaque",
          stringData: {
            text: fetchJenkinsToken.stdout,
          },
        },
        {
          dependsOn: [fetchJenkinsToken],
          provider: clusterK8sProvider,
        }
      );

    }

  });

}

execute();
