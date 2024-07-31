import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  clusterName: process.env.CLUSTER_NAME,
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID,
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,

  // Cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
};
