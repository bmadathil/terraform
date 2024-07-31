import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  clusterName: process.env.CLUSTER_NAME || "",
  awsRegion: process.env.AWS_DEFAULT_REGION,

  // --- cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
};
