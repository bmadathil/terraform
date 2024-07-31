import * as fs from "fs";
import * as path from "path";
import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";
import { EnvFrom, ExternalSecret } from "../interfaces";
import { createExternalSecret, retrieveCredentials } from "./functions";

interface Workload {
  name: string;
  host?: string;
  envFrom: EnvFrom[];
  adminCredentials: ExternalSecret;
  userCredentials?: ExternalSecret[];
}

const POSTGRES = "postgres";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;
    const key = `${namespace}-${POSTGRES}`;

    const createConfigMap = (host?: string) => {
      return new k8s.core.v1.ConfigMap(
        `${key}-configmap`,
        {
          metadata: {
            name: `${POSTGRES}-configmap`,
            namespace,
          },
          data: {
            POSTGRES_HOST: host || POSTGRES,
            POSTGRES_DB: POSTGRES,
            POSTGRES_PORT: "5432",
            PGHOST: host || POSTGRES,
            PGDATABASE: POSTGRES,
            PGPORT: "5432",
          },
        },
        { provider: clusterK8sProvider }
      );
    }

    let workload: Workload = ns.workloads.find((wl: Workload) => {
      return (
        wl.name === POSTGRES &&
        wl.userCredentials && wl.userCredentials.length > 0
      );
    });

    if (workload) {

      await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );

      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials, true
      );

      workload.userCredentials?.forEach(secret => {
        createExternalSecret(namespace, secret, clusterK8sProvider);
      });

      const fileConfigs = {};
      const directory = path.resolve(__dirname, `scripts-initdb`);

      fs.readdirSync(directory, { withFileTypes: true })
        .forEach(file => {
          let fileContents = fs.readFileSync(`${directory}/${file.name}`, "utf8");
          fileConfigs[file.name] = fileContents;
        });

      const initdbConfigMap = new k8s.core.v1.ConfigMap(
        `${key}-initdb-configmap`,
        {
          metadata: {
            name: `${POSTGRES}-initdb-configmap`,
            namespace,
          },
          data: fileConfigs,
        },
        {
          provider: clusterK8sProvider,
        }
      );

      createConfigMap(POSTGRES);

      new k8s.helm.v3.Release(
        `${key}-deployment`,
        {
          name: POSTGRES,
          namespace,
          chart: "./postgresql",
          values: {
            nameOverride: POSTGRES,
            auth: {
              username: adminCredentials.username,
              existingSecret: workload.adminCredentials.name,
              secretKeys: {
                userPasswordKey: adminCredentials.passwordSecretKey,
                adminPasswordKey: adminCredentials.passwordSecretKey,
              },
            },
            primary: {
              extraEnvVars: [
                ...workload.envFrom,
                {
                  name: "PGDATABASE",
                  value: POSTGRES,
                },
              ],
              initdb: {
                scriptsConfigMap: initdbConfigMap.metadata.name,
              },
            },
          },
        },
        {
          provider: clusterK8sProvider,
        }
      );

    }

  });

}

execute();
