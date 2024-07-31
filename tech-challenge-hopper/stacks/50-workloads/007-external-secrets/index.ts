import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";

const EXTERNAL_SECRETS = "external-secrets";
const namespace = "kube-system";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

const release = new k8s.helm.v3.Release(
  `${EXTERNAL_SECRETS}-release`,
  {
    name: EXTERNAL_SECRETS,
    namespace,
    chart: "./external-secrets",
  },
  {
    provider: clusterK8sProvider,
  }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  const awssmSecret = new k8s.core.v1.Secret(
    "awssm-secret",
    {
      metadata: {
        name: "awssm-secret",
        annotations: {
          "reflector.v1.k8s.emberstack.com/reflection-allowed": "true",
          "reflector.v1.k8s.emberstack.com/reflection-auto-enabled": "true",
          "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces":
            clusterConfig.namespaces.map((ns: { name: string } ) => ns.name).join(","),
        }
      },
      type: "generic",
      stringData: {
        "access-key": config.awsAccessKeyId,
        "secret-access-key": config.awsSecretAccessKey,
      },
    },
  );

  clusterConfig.namespaces.forEach(ns => {

    const namespace = ns.name;

    new k8s.apiextensions.CustomResource(
      `${namespace}-external-secrets-store`,
      {
        apiVersion: "external-secrets.io/v1beta1",
        kind: "SecretStore",
        metadata: {
          name: "external-secrets-store",
          namespace,
        },
        spec: {
          provider: {
            aws: {
              service: "SecretsManager",
              region: "us-east-1",
              auth: {
                secretRef: {
                  accessKeyIDSecretRef: {
                    name: "awssm-secret",
                    key: "access-key",
                  },
                  secretAccessKeySecretRef: {
                    name: "awssm-secret",
                    key: "secret-access-key",
                  },
                },
              },
            },
          },
        },
      },
      {
        dependsOn: [awssmSecret, release],
        provider: clusterK8sProvider
      }
    );

  })

}

execute();
