import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const infrastructureStackRef = new pulumi.StackReference(
  pulumiConfig.require("infrastructureStackRef")
);

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  clusterName: process.env.CLUSTER_NAME || "",

  // Infrastructure / Networking
  vpcId: infrastructureStackRef.getOutput("vpcId"),
  publicSubnetIds: infrastructureStackRef.getOutput("publicSubnetIds"),
  privateSubnetIds: infrastructureStackRef.getOutput("privateSubnetIds"),

  // --- cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
  clusterOidcProviderUrl: serviceStackRef.getOutput("clusterOidcProviderUrl"),
  securityGroupIds: serviceStackRef.getOutput("securityGroupIds"),  
};
