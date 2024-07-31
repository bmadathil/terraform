import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const identityStackRef = new pulumi.StackReference(
  pulumiConfig.require("identityStackRef")
);
const infrastructureStackRef = new pulumi.StackReference(
  pulumiConfig.require("infrastructureStackRef")
);
const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  clusterName: process.env.CLUSTER_NAME || "",
  githubUser: process.env.GITHUB_USER || "",
  githubPat: process.env.GITHUB_USER_PAT || "",
  seedJobRepoUrl: process.env.SEED_JOB_REPO_URL || "",

  // identity
  teamsChannelUrl: identityStackRef.getOutput("teamsChannelUrl"),

  // Infra
  privateSubnetIds: infrastructureStackRef.getOutput("privateSubnetIds"),
  publicSubnetIds: infrastructureStackRef.getOutput("publicSubnetIds"),
  publicHostedZoneName: infrastructureStackRef.getOutput("publicHostedZoneName"),
  publicHostedZoneId: infrastructureStackRef.getOutput("publicHostedZoneId"),
  privateHostedZoneName: infrastructureStackRef.getOutput("privateHostedZoneName"),
  privateHostedZoneId: infrastructureStackRef.getOutput("privateHostedZoneId"),

  // Cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
  clusterOidcProviderUrl: serviceStackRef.getOutput("clusterOidcProviderUrl"),
  securityGroupIds: serviceStackRef.getOutput("securityGroupIds"),
};
