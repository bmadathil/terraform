import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";

interface Workload {
  name: string;
  host: string;
  replicas: number;
}

const SMTP4DEV = "smtp4dev";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === SMTP4DEV
    );

    if (workload) {

      new k8s.helm.v3.Release(
        `${SMTP4DEV}-release`,
        {
          name: SMTP4DEV,
          namespace,
          chart: "./smtp4dev",
          values: {
            replicaCount: workload.replicas,
            affinity: {
              nodeAffinity: {
                requiredDuringSchedulingIgnoredDuringExecution: {
                  nodeSelectorTerms: [
                    {
                      matchExpressions: [
                        {
                          key: "kubernetes.io/os",
                          operator: "In",
                          values: ["linux"],
                        },
                      ],
                    },
                  ],
                },
              },
            }
          },
        },
        { provider: clusterK8sProvider }
      );

      new k8s.apiextensions.CustomResource(
        `${SMTP4DEV}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: `${SMTP4DEV}-ingressroute`,
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
                    name: SMTP4DEV,
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

  })

}

execute();
