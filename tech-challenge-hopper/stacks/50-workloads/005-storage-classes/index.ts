import * as k8s from "@pulumi/kubernetes";
import { config } from "./config";

const clusterK8sProvider = new k8s.Provider("k8s", {
  kubeconfig: config.kubeconfig,
});

// --- storage classes

const gp2Expanding = new k8s.storage.v1.StorageClass(
  "gp2-expanding",
  {
    metadata: {
      name: "gp2-expanding",
    },
    parameters: {
      type: "gp2",
    },
    provisioner: "kubernetes.io/aws-ebs",
    allowVolumeExpansion: true,
    mountOptions: ["debug"],
    reclaimPolicy: "Delete",
    volumeBindingMode: "WaitForFirstConsumer",
  }
);
