import * as k8s from "@pulumi/kubernetes";
import { config } from "./config";

const clusterK8sProvider = new k8s.Provider("k8s", {
  kubeconfig: config.kubeconfig,
});

// --- ebs csi driver
// --- https://github.com/kubernetes-sigs/aws-ebs-csi-driver

const ebsCsiDriverName = "aws-ebs-csi-driver";

const ebsCsiDriver = new k8s.helm.v3.Release(
  ebsCsiDriverName,
  {
    name: ebsCsiDriverName,
    namespace: "kube-system",
    chart: "./aws-ebs-csi-driver",
  },
  { provider: clusterK8sProvider }
);
