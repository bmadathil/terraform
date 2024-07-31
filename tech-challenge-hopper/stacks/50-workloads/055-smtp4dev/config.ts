import * as pulumi from "@pulumi/pulumi";

let pulumiConfig = new pulumi.Config();

const serviceStackRef = new pulumi.StackReference(
  pulumiConfig.require("serviceStackRef")
);

export const config = {
  // cluster
  kubeconfig: serviceStackRef.getOutput("kubeconfig"),
};
