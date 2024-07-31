import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";
import * as kq from "@pulumi/query-kubernetes";
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";
import * as cmd from "@pulumi/command";
import { config } from "./config";

const otelNamespace = new k8s.core.v1.Namespace('otel', {
    metadata: {
        name:'otel',
    },
});

// Export the namespace name
exports.namespaceName = otelNamespace.metadata.name;

const clusterK8sProvider = new k8s.Provider("k8s", {
  kubeconfig: config.kubeconfig,
});

const namespaceName = 'otel'; // Replace with your namespace name
const releaseName = 'otel'; // Replace with your Helm release name

// Define the values for otel Helm chart
const otelChartValues = {
      global: {
        storageClass: 'gp2-resizable',
        cloud: 'aws',
      },    
      
      clickhouse: {
        installCustomStorageClass: true,
      },
};
const otelChart = new k8s.helm.v3.Chart("otel", {
    repo: "signoz",
    chart: "signoz",
    fetchOpts: {
        repo: 'https://charts.signoz.io',
    },
    version: '0.31.2', 
    namespace: 'otel',
    values: otelChartValues,
});



const jenkinsIngressRoute = new k8s.apiextensions.CustomResource(
  "otel-ingressroute",
  {
    apiVersion: "traefik.io/v1alpha1",
    kind: "IngressRoute",
    metadata: {
      name: "otel",
      namespace: "otel",
    },
    spec: {
      entryPoints: ["websecure"],
      routes: [
        {
          match: "Host(`monitor.hopper.sandbox.cvpcorp.io`)", // TODO: externalize
          kind: "Rule",
          services: [
            {
              name: "otel-signoz-frontend",
              kind: "Service",
              namespace: "otel",
              port: 3301,
            },
          ],
        },
      ],
      tls: {
        certResolver: "le",
      },
    },
  }
);
