import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

new k8s.yaml.ConfigFile(
  "kubernetes-reflector-extension",
  {
    file: `https://github.com/emberstack/kubernetes-reflector/releases/latest/download/reflector.yaml`,
  },
  { provider: clusterK8sProvider }
);
