import * as aws from "@pulumi/aws";
import * as eks from "@pulumi/eks";
import * as pulumi from "@pulumi/pulumi";

import { config } from "./config.js";

const clusterName = config.clusterName;
const projectName = pulumi.getProject();
const kubernetesVersion = config.k8sVersion;

export const adminsIamRoleArn = config.adminsIamRoleArn;
export const stdNodegroupIamRoleArn = config.stdNodegroupIamRoleArn;

const stdNodegroupIamRoleName = stdNodegroupIamRoleArn
  .apply((s) => s.split("/"))
  .apply((s) => s[1]);

new aws.ec2.SecurityGroup(`${clusterName}-db-sg`, {
  description: "Permit RDS access to node group",
  vpcId: config.vpcId,
  ingress: [
    {
      description: "PostgreSQL",
      fromPort: 5432,
      toPort: 5432,
      protocol: "tcp",
      self: true,
    },
  ],
  egress: [
    {
      fromPort: 5432,
      toPort: 5432,
      protocol: "tcp",
      self: true,
    },
  ],
  tags: {
    Name: "PostgreSQL access",
  },
});

const cluster = new eks.Cluster(`${clusterName}`, {
  name: clusterName,
  version: kubernetesVersion,
  vpcId: config.vpcId,
  publicSubnetIds: config.publicSubnetIds,
  privateSubnetIds: config.privateSubnetIds,
  createOidcProvider: true,
  instanceRoles: [aws.iam.Role.get("adminsIamRole", stdNodegroupIamRoleName)],
  roleMappings: [
    {
      roleArn: config.adminsIamRoleArn,
      groups: ["system:masters"],
      username: "admin",
    },
  ],
  storageClasses: {
    "gp2-encrypted": { type: "gp2", encrypted: true },
    sc1: { type: "sc1" },
  },
  nodeAssociatePublicIpAddress: false,
  skipDefaultNodeGroup: true,
  clusterSecurityGroupTags: { ClusterSecurityGroupTag: "true" },
  nodeSecurityGroupTags: { NodeSecurityGroupTag: "true" },
  enabledClusterLogTypes: [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ],
  tags: {
    Project: `${projectName}`,
  },
});

// create secure string parameter in Systems Manager for kubeconfig (EKS)
const paramKubeconfig = new aws.ssm.Parameter(`${clusterName}-kubeconfig`, {
  name: `/${clusterName}/kubeconfig`,
  type: "SecureString",
  value: cluster.kubeconfig.apply(JSON.stringify),
});
export const kubeconfigParamName = paramKubeconfig.name;

// export cluster details
export const kubeconfig = cluster.kubeconfig.apply(JSON.stringify);
export const clusterOidcProviderUrl = cluster.core.oidcProvider?.url.apply(
  (url) => url.replace("https://", "")
);
export const region = aws.config.region;
export const clusterSecurityGroupIds = [cluster.nodeSecurityGroup.id];

new aws.rds.SubnetGroup(`${clusterName}-subnets`, {
  // TODO: change to private after testing is completed
  subnetIds: config.publicSubnetIds,
});
