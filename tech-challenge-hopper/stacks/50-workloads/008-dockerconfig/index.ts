import { Base64 } from "js-base64";
import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";

const githubUser = config.githubUser;
const githubPat = config.githubPat;

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();
  let authString = Base64.encode(`${githubUser}:${githubPat}`);

  new k8s.core.v1.Secret(
    "ghcr-pull-secret",
    {
      metadata: {
        name: "ghcr-pull-secret",
        annotations: {
          "reflector.v1.k8s.emberstack.com/reflection-allowed": "true",
          "reflector.v1.k8s.emberstack.com/reflection-auto-enabled": "true",
          "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces":
            clusterConfig.namespaces.map((ns: { name: string } ) => ns.name).join(","),
        }
      },
      type: "kubernetes.io/dockerconfigjson",
      data: {
        ".dockerconfigjson": Base64.encode(
          `{"auths":{"ghcr.io":{"auth":"${authString}"}}}`
        ),
      },
    },
    { provider: clusterK8sProvider }
  );

}

execute();
