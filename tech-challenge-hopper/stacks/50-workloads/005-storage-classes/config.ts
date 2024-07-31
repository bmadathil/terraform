import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  // Cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
  clusterName: serviceStackRef.getOutput("clusterName"),
  clusterOidcProviderUrl: serviceStackRef.getOutput("clusterOidcProviderUrl"),
  securityGroupIds: serviceStackRef.getOutput("securityGroupIds"),
};
