import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const identityStackRef = new pulumi.StackReference(
  pulumiConfig.require("identityStackRef")
);

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  clusterName: process.env.CLUSTER_NAME,
  githubUser: process.env.GITHUB_USER,
  githubPat: process.env.GITHUB_USER_PAT,

  // Cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
  clusterOidcProviderUrl: serviceStackRef.getOutput("clusterOidcProviderUrl"),
  securityGroupIds: serviceStackRef.getOutput("securityGroupIds"),
};
