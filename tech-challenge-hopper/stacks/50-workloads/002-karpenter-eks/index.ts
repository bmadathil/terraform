import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";
import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";

const KARPENTER = "karpenter";
const KARPENTER_VERSION = "0.37.0";//THIS MUST MATCH CHART
const crds: k8s.yaml.ConfigFile[] = [];
const clusterName = config.clusterName;
const identity = aws.getCallerIdentity();
const nodeRoleName = `KarpenterNodeRole-${clusterName}`;
const controllerRoleName = `KarpenterControllerRole-${clusterName}`;

const clusterK8sProvider = new k8s.Provider("k8s", {
  kubeconfig: config.kubeconfig,
});

crds.push(
  new k8s.yaml.ConfigFile(
    `${KARPENTER}-node-pools-crd`,
    {
      file: `https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${KARPENTER_VERSION}/pkg/apis/crds/karpenter.sh_nodepools.yaml`,
    },
    { provider: clusterK8sProvider }
  )
);

crds.push(
  new k8s.yaml.ConfigFile(
    `${KARPENTER}-ec2-node-classes-crd`,
    {
      file: `https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${KARPENTER_VERSION}/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml`,
    },
    { provider: clusterK8sProvider }
  )
);

crds.push(
  new k8s.yaml.ConfigFile(
    `${KARPENTER}-node-claims-crd`,
    {
      file: `https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${KARPENTER_VERSION}/pkg/apis/crds/karpenter.sh_nodeclaims.yaml`,
    },
    { provider: clusterK8sProvider }
  )
);

const release = pulumi.all([
  identity.then(i => i.accountId),
])
.apply(([accountId]) => {
  return new k8s.yaml.ConfigFile(
    `${KARPENTER}-release`,
    {
      file: "karpenter.yaml",
      transformations: [
        (obj: any) => {
          if (obj.kind === "ServiceAccount" && obj.apiVersion === "v1") {
            obj.metadata.annotations = JSON.parse(`{
              "eks.amazonaws.com/role-arn": "arn:aws:iam::${accountId}:role/${controllerRoleName}"
            }`);
          }
        },
        (obj: any) => {
          if (obj.kind === "Deployment" && obj.apiVersion === "apps/v1") {
            const controller = obj.spec.template.spec.containers
              .find((i: { name: string }) => i.name === "controller");

            const clusterNameEnv = controller.env
              .find((i: { name: string }) => i.name === "CLUSTER_NAME");

            clusterNameEnv.value = clusterName;
            
            obj.spec.template.spec.affinity = {
              nodeAffinity: {
                requiredDuringSchedulingIgnoredDuringExecution: {
                  nodeSelectorTerms: [
                    {
                      matchExpressions: [
                        {
                          key: "karpenter.sh/nodepool",
                          operator: "DoesNotExist",
                        },
                        {
                          key: "eks.amazonaws.com/nodegroup",
                          operator: "In",
                          values: [ `${clusterName}-ng` ],
                        },
                      ],
                    },
                  ],
                },
              },
              podAntiAffinity: {
                requiredDuringSchedulingIgnoredDuringExecution: [
                  { topologyKey: "kubernetes.io/hostname" },
                ],
              }
            }
          }
        },
      ],
    },
    {
      dependsOn: [...crds],
      provider: clusterK8sProvider,
    }
  );
});

const ec2NodeClasses = new k8s.apiextensions.CustomResource(
  `${KARPENTER}-ec2-node-class`,
  {
    apiVersion: "karpenter.k8s.aws/v1beta1",
    kind: "EC2NodeClass",
    metadata: { name: "default" },
    spec: {
      amiFamily: "AL2",
      role: nodeRoleName,
      subnetSelectorTerms: [
        {
          tags: {
            "karpenter.sh/discovery": clusterName,
          },
        },
      ],
      securityGroupSelectorTerms: [
        {
          tags: {
            "karpenter.sh/discovery": clusterName,
          },
        },
      ],
    },
  },
  {
    dependsOn: [release],
    provider: clusterK8sProvider,
  }
);

new k8s.yaml.ConfigFile(
  `${KARPENTER}-node-pool`,
  {
    file: "node-pool.yaml",
  },
  {
    dependsOn: [ec2NodeClasses],
    provider: clusterK8sProvider,
  }
);
