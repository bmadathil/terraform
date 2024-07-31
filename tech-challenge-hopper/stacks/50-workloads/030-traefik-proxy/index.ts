import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";
import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { ExternalSecret } from "../interfaces";
import { createExternalSecret } from "./functions";
import { getClusterConfig } from "../cluster-config";

interface Workload {
  name: string;
  host: string;
  email: string;
  adminCredentials: ExternalSecret;
  hostedZones: [{
    name: string;
    records: string[];
  }];
}

const TRAEFIK = "traefik";

const caller = aws.getCallerIdentity();

const traefikRoleArn = pulumi
  .all([
    caller.then((c) => c.accountId),
  ])
  .apply(([accountId]) => {
    return `arn:aws:iam::${accountId}:role/eks-traefik-controller`;
  });

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;

    // SHOULD ONLY HAVE ONE TRAEFIK WORKLOAD PER CLUSTER
    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === TRAEFIK
    );

    if (workload) {

      const adminCredentials = await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );

      const traefik = new k8s.helm.v3.Release(
        `${TRAEFIK}-release`,
        {
          name: TRAEFIK,
          namespace,
          chart: "./traefik",
          values: {
            image: {
              tag: "v3.0.0-beta5", // using beta for tracing support
            },
            certResolvers: {
              le: {
                email: workload.email,
                tlsChallenge: true,
                storage: "/data/acme.json",
              },
            },
            deployment: {
              initContainers: [
                {
                  // mitigate potential file permissions lost on restart
                  name: "volume-permissions",
                  image: "busybox:latest",
                  command: [
                    "sh",
                    "-c",
                    "touch /data/acme.json && chmod -Rv 600 /data/* && chown 65532:65532 /data/acme.json",
                  ],
                  securityContext: {
                    runAsNonRoot: false,
                    runAsGroup: 0,
                    runAsUser: 0,
                  },
                  volumeMounts: [
                    {
                      name: "data",
                      mountPath: "/data",
                    },
                  ],
                },
              ],
            },
            // used for LE certs
            persistence: {
              enabled: true,
              name: "data",
              accessMode: "ReadWriteOnce",
              size: "128Mi",
              path: "/data",
            },
            serviceAccountAnnotations: {
              "eks.amazonaws.com/role-arn": traefikRoleArn,
            },
            service: {
              annotations: {
                "service.beta.kubernetes.io/aws-load-balancer-type": "nlb",
                "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing",
              },
            },
            additionalArguments: [
              `--certificatesresolvers.le.acme.caserver=${config.certificateServer}`,
            ],
          },
        },
        { provider: clusterK8sProvider }
      );

      const basicAuthMiddleware = new k8s.apiextensions.CustomResource(
        `${TRAEFIK}-basic-auth-middleware`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "Middleware",
          metadata: {
            name: "basic-auth-middleware",
            namespace,
          },
          spec: {
            basicAuth: {
              secret: workload.adminCredentials.name,
            },
          },
        },
        {
          dependsOn: [adminCredentials, traefik],
          provider: clusterK8sProvider,
        }
      );

      new k8s.apiextensions.CustomResource(
        `${TRAEFIK}-insecure-server-transport`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "ServersTransport",
          metadata: {
            name: "insecure-server-transport",
            namespace,
          },
          spec: {
            insecureSkipVerify: true,
          },
        },
        {
          dependsOn: [traefik],
          provider: clusterK8sProvider,
        }
      );

      const ingressRoute = new k8s.apiextensions.CustomResource(
        `${TRAEFIK}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: TRAEFIK,
            namespace,
          },
          spec: {
            entryPoints: [ TRAEFIK, "websecure" ],
            routes: [
              {
                kind: "Rule",
                match: `Host(\`${workload.host}\`)`,
                middlewares: [
                  { name: basicAuthMiddleware.metadata.name },
                ],
                services: [
                  {
                    name: TRAEFIK,
                    kind: "Service",
                    namespace,
                    port: 80,
                  },   
                  {
                    name: TRAEFIK,
                    kind: "Service",
                    namespace,
                    port: 443,
                  },
                ],
              },
            ],
            tls: { certResolver: "le" },
          },
        },
        { provider: clusterK8sProvider }
      );

      const service = k8s.core.v1.Service.get(
        `${TRAEFIK}-service`,
        pulumi.interpolate`${namespace}/${TRAEFIK}`,
        {
          dependsOn: [ingressRoute],
          provider: clusterK8sProvider
        }
      );

      const externalIp = service.status.apply(status => {
        const ingress = status.loadBalancer?.ingress;
        if (ingress && ingress.length > 0) {
          return ingress[0].ip || ingress[0].hostname;
        }
        return "No external IP found";
      });

      workload.hostedZones.forEach(async (zone) => {

        const hostedZone = await aws.route53.getZone({ name: zone.name });

        zone.records.forEach((record: string) => {
 
          new aws.route53.Record(
            `${record}.${zone.name}`,
            {
              zoneId: hostedZone.id,
              name: `${record}.${zone.name}`,
              type: aws.route53.RecordType.CNAME,
              ttl: 300,
              records: [ externalIp ]
            }
          );

        })

      });

    }

  });
}

execute();
