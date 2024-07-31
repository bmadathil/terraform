import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";
import { config } from "./config";

const userClusterName = process.env.CLUSTER_NAME;
const publicHostedZoneId = config.publicHostedZoneId;
const privateHostedZoneId = config.privateHostedZoneId;

const caller = aws.getCallerIdentity();
const region = aws.getRegion();

const clusterOidcProviderUrl = config.clusterOidcProviderUrl;
const clusterOidcProviderArn = pulumi
  .all([
    caller.then((caller) => caller.accountId),
    region.then((region) => region.name),
    clusterOidcProviderUrl,
  ])
  .apply(([accountId, region, url]) => {
    return `arn:aws:iam::${accountId}:oidc-provider/${url}`;
  });

const clusterK8sProvider = new k8s.Provider("k8s", {
  kubeconfig: config.kubeconfig,
});

// --- k8s dashboard
// --- https://github.com/kubernetes/dashboard

const k8sDashName = "kubernetes-dashboard";

const k8sDashPolicy = new aws.iam.Policy(k8sDashName, {
  path: `/${userClusterName}-policies/`,
  description: "k8sDash policy",
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: ["route53:ChangeResourceRecordSets"],
        Resource: [
          `arn:aws:route53:::hostedzone/${publicHostedZoneId}`,
          `arn:aws:route53:::hostedzone/${privateHostedZoneId}`,
        ],
      },
      {
        Effect: "Allow",
        Action: ["route53:ListHostedZones", "route53:ListResourceRecordSets"],
        Resource: ["*"],
      },
    ],
  }),
});

const k8sDashAssumeRolePolicy = pulumi
  .all([clusterOidcProviderUrl, clusterOidcProviderArn])
  .apply(([url, arn]) =>
    aws.iam.getPolicyDocument({
      statements: [
        {
          actions: ["sts:AssumeRoleWithWebIdentity"],
          conditions: [
            {
              test: "StringEquals",
              values: [`system:serviceaccount:${k8sDashName}:${k8sDashName}`],
              variable: `${url}:sub`,
            },
            {
              test: "StringEquals",
              values: ["sts.amazonaws.com"],
              variable: `${url}:aud`,
            },
          ],
          effect: "Allow",
          principals: [{ identifiers: [arn], type: "Federated" }],
        },
      ],
    })
  );

const k8sDashRole = new aws.iam.Role(`${userClusterName}-${k8sDashName}-role`, {
  assumeRolePolicy: k8sDashAssumeRolePolicy.json,
});

const k8sDashRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
  k8sDashName,
  {
    policyArn: k8sDashPolicy.arn,
    role: k8sDashRole,
  }
);

const k8sDashNs = new k8s.core.v1.Namespace(
  k8sDashName,
  {
    metadata: { name: k8sDashName },
  },
  { provider: clusterK8sProvider }
);

const k8sDashServiceAccount = new k8s.core.v1.ServiceAccount(
  k8sDashName,
  {
    metadata: {
      namespace: k8sDashName,
      name: k8sDashName,
      annotations: {
        "eks.amazonaws.com/role-arn": k8sDashRole.arn,
      },
    },
  },
  { provider: clusterK8sProvider, dependsOn: [k8sDashNs, k8sDashRole] }
);

// TODO: this is cluster admin role for full access to dashboard capabilities; should make a
// new role for devs and/or a read only role
const k8sDashServiceAccountClusterRoleBinding =
  new k8s.rbac.v1.ClusterRoleBinding(
    k8sDashName,
    {
      metadata: {
        name: k8sDashName,
      },
      roleRef: {
        apiGroup: "rbac.authorization.k8s.io",
        kind: "ClusterRole",
        name: "cluster-admin",
      },
      subjects: [
        {
          kind: "ServiceAccount",
          name: k8sDashName,
          namespace: k8sDashName,
        },
      ],
    },
    { provider: clusterK8sProvider, dependsOn: [k8sDashNs] }
  );

const k8sDashServiceAccountToken = new k8s.core.v1.Secret(
  k8sDashName,
  {
    metadata: {
      namespace: k8sDashName,
      name: k8sDashName,
      annotations: {
        "kubernetes.io/service-account.name": k8sDashName,
      },
    },
    type: "kubernetes.io/service-account-token",
  },
  { provider: clusterK8sProvider, dependsOn: [k8sDashServiceAccount] }
);

const k8sDash = new k8s.helm.v3.Release(
  k8sDashName,
  {
    name: k8sDashName,
    namespace: k8sDashName,
    chart: "./kubernetes-dashboard",
    values: {
      service: {
        externalPort: 8080
      },
      serviceAccount: {
        create: false,
        name: k8sDashName,
      },
    },
  },
  {
    dependsOn: [k8sDashNs],
    provider: clusterK8sProvider,
  }
);

const ingressRoute = new k8s.apiextensions.CustomResource(
  `${k8sDashName}-ingress-route`,
  {
    apiVersion: "traefik.io/v1alpha1",
    kind: "IngressRoute",
    metadata: {
      name: k8sDashName,
      namespace: k8sDashName,
    },
    spec: {
      entryPoints: ["websecure"],
      routes: [
        {
          kind: "Rule",
          match: "Host(`dash.falcon.sandbox.cvpcorp.io`)", // TODO: externalize
          services: [
            {
              kind: "Service",
              name: k8sDashName,
              namespace: k8sDashName,
              port: 8080,
              serversTransport: "insecure-servers-transport",
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
