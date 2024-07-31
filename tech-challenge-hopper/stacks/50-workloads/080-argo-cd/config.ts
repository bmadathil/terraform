import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const infrastructureStackRef = new pulumi.StackReference(
  pulumiConfig.require("infrastructureStackRef")
);

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  githubUser: process.env.GITHUB_USER || "",
  githubPat: process.env.GITHUB_USER_PAT || "",

  // Infra
  privateSubnetIds: infrastructureStackRef.getOutput("privateSubnetIds"),
  publicSubnetIds: infrastructureStackRef.getOutput("publicSubnetIds"),
  publicHostedZoneName: infrastructureStackRef.getOutput(
    "publicHostedZoneName"
  ),
  publicHostedZoneId: infrastructureStackRef.getOutput("publicHostedZoneId"),
  privateHostedZoneName: infrastructureStackRef.getOutput(
    "privateHostedZoneName"
  ),
  privateHostedZoneId: infrastructureStackRef.getOutput("privateHostedZoneId"),

  // Cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
  clusterName: serviceStackRef.getOutput("clusterName"),
  clusterOidcProviderUrl: serviceStackRef.getOutput("clusterOidcProviderUrl"),
  securityGroupIds: serviceStackRef.getOutput("securityGroupIds"),
};
