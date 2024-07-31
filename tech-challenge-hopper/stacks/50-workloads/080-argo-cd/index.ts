import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";

interface Workload {
  name: string;
  host: string;
  gitRepo: string;
  applications: [{
    name: string;
    path: string;
    environments: string[];
  }];
}

const ARGOCD = "argocd";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {
  
  const clusterConfig = await getClusterConfig();
 
  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;
    const key = `${namespace}-${ARGOCD}`;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === ARGOCD
    );

    if (workload) {

      const release = new k8s.helm.v3.Release(
        `${key}-release`,
        {
          name: ARGOCD,
          namespace,
          chart: "./argo-cd",
          skipAwait: true,
          values: {
            configs: {
              credentialTemplates: {
                "https-creds": {
                  url: workload.gitRepo,
                  password: config.githubPat,
                  username: config.githubUser,
                },
              },
            },
            repositories: {
              "private-repo": {
                url: workload.gitRepo,
              },
            },
            server: {
              extraArgs: ["--insecure"],
            },
          },
        },
        {
          provider: clusterK8sProvider,
          ignoreChanges: ["values", "version"],
        }
      );

      new k8s.apiextensions.CustomResource(
        `${key}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: `${ARGOCD}-ingressroute`,
            namespace,
          },
          spec: {
            entryPoints: ["websecure"],
            routes: [
              {
                kind: "Rule",
                match: `Host(\`${workload.host}\`)`,
                services: [
                  {
                    name: `${ARGOCD}-server`,
                    kind: "Service",
                    namespace,
                    port: 80,
                  },
                ],
              },
            ],
            tls: { certResolver: "le" },
          },
        },
        {
          dependsOn: [release],
          provider: clusterK8sProvider,
        }
      );

      workload.applications.forEach(app => {

        app.environments.forEach(env => {

          new k8s.apiextensions.CustomResource(
            `${ARGOCD}-${app.name}-${env}`,
            {
              apiVersion: "argoproj.io/v1alpha1",
              kind: "Application",
              metadata: {
                name: `${app.name}-${env}`,
                namespace,
              },
              spec: {
                project: "default",
                source: {
                  repoURL: workload.gitRepo,
                  targetRevision: "HEAD",
                  path: `${app.path}/${env}`,
                },
                destination: {
                  server: "https://kubernetes.default.svc",
                  namespace: env,
                },
                syncPolicy: {
                  automated: {
                    selfHeal: true,
                    prune: true,
                  },
                },
              },
            },
            {
              dependsOn: [release],
              provider: clusterK8sProvider,
            }
          );

        });

      });

    }
  
  });

}

execute();
