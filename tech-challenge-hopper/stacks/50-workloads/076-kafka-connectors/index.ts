import * as fs from "fs";
import * as path from "path";
import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";

interface Workload {
  name: string;
  connect: {
    connectors: [{
      name: string;
      substitutions: [{
        key: string;
        value: string;
      }]
    }];
  }
}

const CONNECT = "connect";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {
  
  const clusterConfig = await getClusterConfig();
 
  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === "kafka"
    );

    if (workload) {

      workload.connect.connectors.forEach(connector => {

        const data = {};
        const filename = `${connector.name}.json`;
        const mountPath = `/tmp/${filename}`;

        const dirPath = path.resolve(__dirname, `./connectors`);
        let fileContents = fs.readFileSync(`${dirPath}/${filename}`, "utf8");
        const configJson = JSON.parse(fileContents);

        connector.substitutions?.forEach(sub => {
          configJson[sub.key] = sub.value;
        });
        data[filename] = JSON.stringify(configJson);

        let key = `${namespace}-${connector.name}`;
        const configMap = new k8s.core.v1.ConfigMap(
          `${key}-configmap`,
          {
            metadata: {
              name: `${connector.name}-configmap`,
              namespace,
            },
            data,
          },
          { provider: clusterK8sProvider }
        );

        new k8s.batch.v1.Job(
          `create-${key}-connector`,
          {
            metadata: {
              name: `create-${connector.name}-connector`,
              namespace,
            },
            spec: {
              backoffLimit: 5,
              template: {
                spec: {
                  volumes: [
                    {
                      name: "config",
                      configMap: { name: configMap.metadata.name }
                    }
                  ],
                  containers: [
                    {
                      name: "curl-jq",
                      image: "softonic/curl-jq:3.18.3",
                      volumeMounts: [
                        {
                          name: "config",
                          readOnly: true,
                          subPath: filename,
                          mountPath,
                        }
                      ],
                      command: [
                        "curl", "-i", "-X", "PUT",
                        `http://${CONNECT}:8083/connectors/${connector.name}/config`,
                        "-H", "Accept:application/json",
                        "-H", "Content-Type:application/json",
                        "-d", `@${mountPath}`,
                      ],
                    },
                  ],
                  restartPolicy: "Never",
                },
              },
            },
          },
          { provider: clusterK8sProvider }
        );

      });

    }

  });

}

execute();
