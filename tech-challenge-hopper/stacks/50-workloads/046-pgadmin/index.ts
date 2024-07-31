import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { ExternalSecret } from "../interfaces";
import { getClusterConfig } from "../cluster-config";
import { createExternalSecret, retrieveCredentials } from "./functions";

const PGADMIN = "pgadmin";
const POSTGRES = "postgres";

interface Workload {
  name: string;
  host: string;
  replicas: number;
  adminCredentials: ExternalSecret;
}

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const servers = {};
  const pgport = 5432;
  const stringData = { pgpassfile: "" };
  const pgpassfile = "/var/lib/pgadmin/pgpassfile";
  const clusterConfig = await getClusterConfig();

  for(var i=0; i<clusterConfig.namespaces.length; i++) {
    const ns = clusterConfig.namespaces[i];

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === POSTGRES
    );

    if (workload) {

      const credentials = await retrieveCredentials(
        workload.adminCredentials, true
      );

      servers[`${i}`] = {
        Name: ns.name,
        Group: "Servers",
        Host: `${POSTGRES}.${ns.name}.svc.cluster.local`,
        Port: pgport,
        Username: credentials.username,
        SSLMode: "prefer",
        MaintenanceDB: POSTGRES,
        PassFile: pgpassfile,
      }

      stringData.pgpassfile += `${POSTGRES}.${ns.name}.svc.cluster.local:${pgport}:${POSTGRES}:${credentials.username}:${credentials.password}
`;

    }

  }

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === PGADMIN
    );

    if (workload) {

      new k8s.core.v1.Secret(
        "pgpassfile",
        {
          metadata: {
            name: "pgpassfile",
            namespace,
          },
          type: "Opaque",
          stringData,
        }
      );

      const adminSecret = await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );

      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials, true
      );

      new k8s.helm.v3.Release(
        `${PGADMIN}-deployment`,
        {
          name: PGADMIN,
          namespace,
          chart: "./pgadmin4",
          values: {
            replicaCount: workload.replicas,
            existingSecret: workload.adminCredentials.name,
            secretKeys: {
              pgadminPasswordKey: adminCredentials.passwordSecretKey,
            },
            env: {
              pgpassfile: pgpassfile,
              email: adminCredentials.username,
            },
            serverDefinitions: {
              enabled: true,
              servers,
            },
            extraSecretMounts: [
              {
                name: "pgpassfile",
                secret: "pgpassfile",
                subPath: "pgpassfile",
                mountPath: "/tmp/pgpassfile",
              },
            ],
            VolumePermissions: { enabled: true },
            extraInitContainers: `
- name: setup-pgpassfile
  image: "dpage/pgadmin4:latest"
  command: [
    "sh", "-c",
    "cp /tmp/pgpassfile ${pgpassfile} && chown 5050:5050 ${pgpassfile} && chmod 0600 ${pgpassfile}"
  ]
  volumeMounts:
    - name: pgadmin-data
      mountPath: /var/lib/pgadmin
    - name: pgpassfile
      subPath: pgpassfile
      mountPath: /tmp/pgpassfile
  securityContext:
    runAsUser: 5050`,
            strategy: {
              type: "Recreate",
            },
          },
        },
        {
          dependsOn: [adminSecret], 
          provider: clusterK8sProvider
        }
      );

      new k8s.apiextensions.CustomResource(
        `${PGADMIN}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: `${PGADMIN}-ingressroute`,
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
                    name: `${PGADMIN}-pgadmin4`,
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
        },
      );

    }

  })

}

execute();
