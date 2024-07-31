import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";
import { config } from "./config";

const userClusterName = process.env.CLUSTER_NAME;
const publicHostedZoneName = config.publicHostedZoneName;
const publicHostedZoneId = config.publicHostedZoneId;
const privateHostedZoneName = config.privateHostedZoneName;
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

// --- external-dns
// --- https://github.com/kubernetes-sigs/external-dns

// TODO: add logic to create or not based on exsitence public/private hosted zones

const extDnsName = "external-dns";

pulumi.all([publicHostedZoneId, privateHostedZoneId]).apply(([publicZoneId, privateZoneId]) => {
  const extDnsPolicy = new aws.iam.Policy(extDnsName, {
    path: `/${userClusterName}-policies/`,
    description: "ExternalDNS policy",
    policy: JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: ["route53:ChangeResourceRecordSets"],
          Resource: [
            `arn:aws:route53:::hostedzone/${publicZoneId}`,
            `arn:aws:route53:::hostedzone/${privateZoneId}`
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

  const extDnsRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
    extDnsName,
    {
      policyArn: extDnsPolicy.arn,
      role: extDnsRole,
    }
  );
});

const extDnsAssumeRolePolicy = pulumi
  .all([clusterOidcProviderUrl, clusterOidcProviderArn])
  .apply(([url, arn]) =>
    aws.iam.getPolicyDocument({
      statements: [
        {
          actions: ["sts:AssumeRoleWithWebIdentity"],
          conditions: [
            {
              test: "StringEquals",
              values: [`system:serviceaccount:${extDnsName}:${extDnsName}`],
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

const extDnsRole = new aws.iam.Role(`${userClusterName}-${extDnsName}-role`, {
  assumeRolePolicy: extDnsAssumeRolePolicy.json,
});

const extDnsNs = new k8s.core.v1.Namespace(
  extDnsName,
  {
    metadata: { name: extDnsName },
  },
  { provider: clusterK8sProvider }
);

const extDnsServiceAccount = new k8s.core.v1.ServiceAccount(
  extDnsName,
  {
    metadata: {
      namespace: extDnsName,
      name: extDnsName,
      annotations: {
        "eks.amazonaws.com/role-arn": extDnsRole.arn,
      },
    },
  },
  { provider: clusterK8sProvider, dependsOn: [extDnsNs, extDnsRole] }
);

// for public zone
const extDnsPublic = new k8s.helm.v3.Release(
  `${extDnsName}-public`,
  {
    name: `${extDnsName}-public`,
    namespace: extDnsName,
    chart: "./external-dns",
    values: {
      aws: {
        zoneType: "public",
      },
      domainFilters: [publicHostedZoneName],
      policy: "sync",
      provider: "aws",
      serviceAccount: {
        create: false,
        name: extDnsName,
      },
      txtOwnerId: publicHostedZoneId,
    },
  },
  {
    dependsOn: [extDnsNs, extDnsServiceAccount],
    provider: clusterK8sProvider,
  }
);

// for private zone
const extDnsPrivate = new k8s.helm.v3.Release(
  `${extDnsName}-private`,
  {
    name: `${extDnsName}-private`,
    namespace: extDnsName,
    chart: "./external-dns",
    values: {
      aws: {
        zoneType: "private",
      },
      domainFilters: [privateHostedZoneName],
      policy: "sync",
      provider: "aws",
      serviceAccount: {
        create: false,
        name: extDnsName,
      },
      txtOwnerId: privateHostedZoneId,
    },
  },
  {
    dependsOn: [extDnsNs, extDnsServiceAccount],
    provider: clusterK8sProvider,
  }
);
