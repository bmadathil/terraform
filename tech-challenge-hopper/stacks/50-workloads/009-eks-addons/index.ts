import * as aws from "@pulumi/aws";

import { config } from "./config";

const clusterName = config.clusterName;

const clusterAddonObservability = new aws.eks.Addon(
  "cluster-addon-observability",
  {
    clusterName: clusterName,
    addonName: "amazon-cloudwatch-observability",
  }
);
