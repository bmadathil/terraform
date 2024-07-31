import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = new k8s.core.v1.Namespace(
      `${ns.name}-namespace`,
      { metadata: { name: ns.name } },
      { provider: clusterK8sProvider }
    );

    const defaultRole = new k8s.rbac.v1.Role(
      `${ns.name}-default-role`,
      {
        metadata: {
          name: "default-role",
          namespace: ns.name,
        },
        rules: [
          {
            apiGroups: [""],
            resources: ["configmaps"],
            verbs: ["get", "list", "patch"],
          },
          {
            apiGroups: ["apps"],
            resources: ["deployments"],
            verbs: ["get", "list", "patch"],
          },
          {
            apiGroups: ["networking.k8s.io"],
            resources: ["ingresses"],
            verbs: ["get", "list"],
          },
        ],
      },
      {
        dependsOn: [namespace],
        provider: clusterK8sProvider,
      }
    );

    new k8s.rbac.v1.RoleBinding(
      `${ns.name}-default-rolebinding`,
      {
        metadata: {
          name: "default-role-binding",
          namespace: ns.name,
        },
        roleRef: {
          apiGroup: "rbac.authorization.k8s.io",
          kind: "Role",
          name: "default-role",
        },
        subjects: [
          {
            kind: "ServiceAccount",
            name: "default",
            namespace: ns.name,
          },
        ],
      },
      {
        dependsOn: [defaultRole],
        provider: clusterK8sProvider,
      }
    );

  });

}

execute();
