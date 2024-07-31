import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const identityStackRef = new pulumi.StackReference(
  pulumiConfig.require("identityStackRef")
);

const infrastructureStackRef = new pulumi.StackReference(
  pulumiConfig.require("infrastructureStackRef")
);

export const config = {
  clusterName: process.env.CLUSTER_NAME || "",
  awsRegion: process.env.AWS_DEFAULT_REGION,
  k8sVersion: process.env.K8S_VERSION,

  // Identity
  adminsIamRoleArn: identityStackRef.getOutput("adminsIamRoleArn"),
  devsIamRoleArn: identityStackRef.getOutput("devsIamRoleArn"),
  stdNodegroupIamRoleArn: identityStackRef.getOutput("stdNodegroupIamRoleArn"),
  perfNodegroupIamRoleArn: identityStackRef.getOutput(
    "perfNodegroupIamRoleArn"
  ),

  // Infrastructure / Networking
  vpcId: infrastructureStackRef.getOutput("vpcId"),
  publicSubnetIds: infrastructureStackRef.getOutput("publicSubnetIds"),
  privateSubnetIds: infrastructureStackRef.getOutput("privateSubnetIds"),
};
