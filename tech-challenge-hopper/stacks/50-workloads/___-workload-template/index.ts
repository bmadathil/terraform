import * as fs from "fs";
import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";
import { config } from "./config";

// TODO: update ___=workload-template

// TODO: config all chart resources for destruction (e.g., EBS volumes) by default

// TODO: add to external config
const seedJobRepositoryHttpsUrl = "https://github.com/CVPcorp/tech-challenge-hopper.git";
const seedJobGroovyFilePath = "seed";

// const projectName = pulumi.getProject();
const userClusterName = process.env.CLUSTER_NAME;
const clusterDomain = process.env.CLUSTER_DOMAIN;
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

const privateSubnetIds = config.privateSubnetIds;
const securityGroupIds = config.securityGroupIds;

// --- environment namespaces
const devNs = new k8s.core.v1.Namespace(
  "hopper-dev",
  {
    metadata: { name: "hopper-dev" },
  },
  { provider: clusterK8sProvider }
);

const testNs = new k8s.core.v1.Namespace(
  "hopper-test",
  {
    metadata: { name: "hopper-test" },
  },
  { provider: clusterK8sProvider }
);

const prodNs = new k8s.core.v1.Namespace(
  "hopper-prod",
  {
    metadata: { name: "hopper-prod" },
  },
  { provider: clusterK8sProvider }
);

// --- ebs csi driver
// --- https://github.com/kubernetes-sigs/aws-ebs-csi-driver

const ebsCsiDriverName = "aws-ebs-csi-driver";

const ebsCsiDriver = new k8s.helm.v3.Release(
  ebsCsiDriverName,
  {
    name: ebsCsiDriverName,
    namespace: "kube-system",
    chart: "./charts/aws-ebs-csi-driver",
  },
  { provider: clusterK8sProvider }
);

// --- cert-manager
// --- https://github.com/cert-manager/cert-manager

// TODO: create ClusterIssuer

const certManagerName = "cert-manager";

const certManagerNs = new k8s.core.v1.Namespace(
  certManagerName,
  {
    metadata: { name: certManagerName },
  },
  { provider: clusterK8sProvider }
);

// const certManagerCrds = new k8s.yaml.ConfigFile(
//   `${certManagerName}-crds`,
//   {
//     file: "./charts/cert-manager/templates/crds.yaml"
//   },
//   { provider: clusterK8sProvider }
// );

const certManagerPolicy = new aws.iam.Policy(certManagerName, {
  path: `/${userClusterName}-policies/`,
  description: "cert-manager policy",
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: ["route53:GetChange"],
        Resource: ["arn:aws:route53:::change/*"],
      },
      {
        Effect: "Allow",
        Action: [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
        ],
        Resource: ["arn:aws:route53:::hostedzone/*"],
      },
      {
        Effect: "Allow",
        Action: ["route53:ListHostedZonesByName"],
        Resource: ["*"],
      },
    ],
  }),
});

const certManagerAssumeRolePolicy = pulumi
  .all([clusterOidcProviderUrl, clusterOidcProviderArn])
  .apply(([url, arn]) =>
    aws.iam.getPolicyDocument({
      statements: [
        {
          actions: ["sts:AssumeRoleWithWebIdentity"],
          conditions: [
            {
              test: "StringEquals",
              values: [
                `system:serviceaccount:${certManagerName}:${certManagerName}`,
              ],
              variable: `${url}:sub`,
            },
          ],
          effect: "Allow",
          principals: [{ identifiers: [arn], type: "Federated" }],
        },
      ],
    })
  );

const certManagerRole = new aws.iam.Role(`${userClusterName}-${certManagerName}-role`, {
  assumeRolePolicy: certManagerAssumeRolePolicy.json,
});

const certManagerRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
  certManagerName,
  {
    policyArn: certManagerPolicy.arn,
    role: certManagerRole,
  }
);

const certManagerServiceAccount = new k8s.core.v1.ServiceAccount(
  certManagerName,
  {
    metadata: {
      namespace: certManagerName,
      name: certManagerName,
      annotations: {
        "eks.amazonaws.com/role-arn": certManagerRole.arn,
      },
    },
  },
  { provider: clusterK8sProvider }
);

const certManager = new k8s.helm.v3.Release(
  certManagerName,
  {
    name: certManagerName,
    namespace: certManagerName,
    chart: "./charts/cert-manager",
    values: {
      installCRDs: true,
      serviceAccount: {
        create: false,
        name: certManagerName
      }
    },
  },
  {
    dependsOn: [certManagerNs],
    provider: clusterK8sProvider,
  }
);

// --- aws load balancer controller
// --- https://github.com/kubernetes-sigs/aws-load-balancer-controller

const awsLbcName = "aws-load-balancer-controller";

const awsLbcPolicy = new aws.iam.Policy("awsLoadBalancerControllerPolicy", {
  path: `/${userClusterName}-policies/`,
  description: "AWS Load Balancer Controller policy",
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: ["iam:CreateServiceLinkedRole"],
        Resource: "*",
        Condition: {
          StringEquals: {
            "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com",
          },
        },
      },
      {
        Effect: "Allow",
        Action: [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
        ],
        Resource: "*",
      },
      {
        Effect: "Allow",
        Action: [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection",
        ],
        Resource: "*",
      },
      {
        Effect: "Allow",
        Action: [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
        ],
        Resource: "*",
        Condition: {
          Null: {
            [`aws:ResourceTag/kubernetes.io/cluster/${userClusterName}`]:
              "false",
          },
        },
      },
      {
        Effect: "Allow",
        Action: ["ec2:CreateSecurityGroup"],
        Resource: "*",
      },
      {
        Effect: "Allow",
        Action: ["ec2:CreateTags"],
        Resource: "arn:aws:ec2:*:*:security-group/*",
        Condition: {
          StringEquals: {
            "ec2:CreateAction": "CreateSecurityGroup",
          },
          Null: {
            "aws:RequestTag/elbv2.k8s.aws/cluster": "false",
          },
        },
      },
      {
        Effect: "Allow",
        Action: ["ec2:CreateTags", "ec2:DeleteTags"],
        Resource: "arn:aws:ec2:*:*:security-group/*",
        Condition: {
          Null: {
            "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
            "aws:ResourceTag/elbv2.k8s.aws/cluster": "false",
          },
        },
      },
      {
        Effect: "Allow",
        Action: [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup",
        ],
        Resource: "*",
        Condition: {
          Null: {
            "aws:ResourceTag/elbv2.k8s.aws/cluster": "false",
          },
        },
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
        ],
        Resource: "*",
        Condition: {
          Null: {
            "aws:RequestTag/elbv2.k8s.aws/cluster": "false",
          },
        },
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
        ],
        Resource: "*",
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
        ],
        Resource: [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
        ],
        Condition: {
          Null: {
            "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
            "aws:ResourceTag/elbv2.k8s.aws/cluster": "false",
          },
        },
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
        ],
        Resource: [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
        ],
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup",
        ],
        Resource: "*",
        Condition: {
          Null: {
            "aws:ResourceTag/elbv2.k8s.aws/cluster": "false",
          },
        },
      },
      {
        "Effect": "Allow",
        "Action": [
          "elasticloadbalancing:AddTags"
        ],
        "Resource": [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ],
        "Condition": {
          "StringEquals": {
            "elasticloadbalancing:CreateAction": [
              "CreateTargetGroup",
              "CreateLoadBalancer"
            ]
          },
          "Null": {
            "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
          }
        }
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
        ],
        Resource: "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      },
      {
        Effect: "Allow",
        Action: [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule",
        ],
        Resource: "*",
      },
    ],
  }),
});

const awsLbcAssumeRolePolicy = pulumi
  .all([clusterOidcProviderUrl, clusterOidcProviderArn])
  .apply(([url, arn]) =>
    aws.iam.getPolicyDocument({
      statements: [
        {
          actions: ["sts:AssumeRoleWithWebIdentity"],
          conditions: [
            {
              test: "StringEquals",
              values: [`system:serviceaccount:kube-system:${awsLbcName}`],
              variable: `${url}:sub`,
            },
          ],
          effect: "Allow",
          principals: [{ identifiers: [arn], type: "Federated" }],
        },
      ],
    })
  );

const awsLbcRole = new aws.iam.Role(`${userClusterName}-${awsLbcName}-role`, {
  assumeRolePolicy: awsLbcAssumeRolePolicy.json,
});

const awsLbcRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
  awsLbcName,
  {
    policyArn: awsLbcPolicy.arn,
    role: awsLbcRole,
  }
);

const awsLbcServiceAccount = new k8s.core.v1.ServiceAccount(
  awsLbcName,
  {
    metadata: {
      namespace: "kube-system",
      name: awsLbcName,
      annotations: {
        "eks.amazonaws.com/role-arn": awsLbcRole.arn,
      },
    },
  },
  { provider: clusterK8sProvider }
);

// const awsLbcCrds = new k8s.yaml.ConfigFile(
//   `${awsLbcName}-crds`,
//   {
//     file: "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml",
//   },
//   { provider: clusterK8sProvider }
// );

const awsLbc = new k8s.helm.v3.Release(
  awsLbcName,
  {
    name: awsLbcName,
    namespace: "kube-system",
    chart: "./charts/aws-load-balancer-controller",

    values: {
      clusterName: userClusterName,
      disableIngressClassAnnotation: true,
      disableIngressGroupNameAnnotation: true,
      serviceAccount: {
        create: false,
        name: awsLbcName,
      },
    },
  },
  {
    dependsOn: [certManager],
    provider: clusterK8sProvider,
  }
);

// --- ACM cert for public domain
// TODO: add logic to create or not based on exsitence public/private hosted zones

// const clusterAlbCert = new aws.acm.Certificate("cluster-alb-cert", {
//   domainName: publicHostedZoneName,
//   subjectAlternativeNames: [publicHostedZoneName.apply((name) => `*.${name}`)],
//   validationMethod: "DNS",
// });

// const clusterAlbCertValidationRecord = new aws.route53.Record(
//   "cluster-alb-cert-validation-record",
//   {
//     name: clusterAlbCert.domainValidationOptions[0].resourceRecordName,
//     records: [clusterAlbCert.domainValidationOptions[0].resourceRecordValue],
//     ttl: 60,
//     type: clusterAlbCert.domainValidationOptions[0].resourceRecordType,
//     zoneId: publicHostedZoneId,
//   }
// );

// const certCertificateValidation = new aws.acm.CertificateValidation("cert", {
//   certificateArn: clusterAlbCert.arn,
//   validationRecordFqdns: [clusterAlbCertValidationRecord.fqdn],
// });

// --- external-dns
// --- https://github.com/kubernetes-sigs/external-dns

// TODO: add logic to create or not based on exsitence public/private hosted zones

// const extDnsName = "external-dns";

// pulumi.all([publicHostedZoneId, privateHostedZoneId]).apply(([publicZoneId, privateZoneId]) => {
//   const extDnsPolicy = new aws.iam.Policy(extDnsName, {
//     path: `/${userClusterName}-policies/`,
//     description: "ExternalDNS policy",
//     policy: JSON.stringify({
//       Version: "2012-10-17",
//       Statement: [
//         {
//           Effect: "Allow",
//           Action: ["route53:ChangeResourceRecordSets"],
//           Resource: [
//             `arn:aws:route53:::hostedzone/${publicZoneId}`,
//             `arn:aws:route53:::hostedzone/${privateZoneId}`
//           ],
//         },
//         {
//           Effect: "Allow",
//           Action: ["route53:ListHostedZones", "route53:ListResourceRecordSets"],
//           Resource: ["*"],
//         },
//       ],
//     }),
//   });

//   const extDnsRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
//     extDnsName,
//     {
//       policyArn: extDnsPolicy.arn,
//       role: extDnsRole,
//     }
//   );
// });

// const extDnsAssumeRolePolicy = pulumi
//   .all([clusterOidcProviderUrl, clusterOidcProviderArn])
//   .apply(([url, arn]) =>
//     aws.iam.getPolicyDocument({
//       statements: [
//         {
//           actions: ["sts:AssumeRoleWithWebIdentity"],
//           conditions: [
//             {
//               test: "StringEquals",
//               values: [`system:serviceaccount:${extDnsName}:${extDnsName}`],
//               variable: `${url}:sub`,
//             },
//             {
//               test: "StringEquals",
//               values: ["sts.amazonaws.com"],
//               variable: `${url}:aud`,
//             },
//           ],
//           effect: "Allow",
//           principals: [{ identifiers: [arn], type: "Federated" }],
//         },
//       ],
//     })
//   );

// const extDnsRole = new aws.iam.Role(`${userClusterName}-${extDnsName}-role`, {
//   assumeRolePolicy: extDnsAssumeRolePolicy.json,
// });

// const extDnsNs = new k8s.core.v1.Namespace(
//   extDnsName,
//   {
//     metadata: { name: extDnsName },
//   },
//   { provider: clusterK8sProvider }
// );

// const extDnsServiceAccount = new k8s.core.v1.ServiceAccount(
//   extDnsName,
//   {
//     metadata: {
//       namespace: extDnsName,
//       name: extDnsName,
//       annotations: {
//         "eks.amazonaws.com/role-arn": extDnsRole.arn,
//       },
//     },
//   },
//   { provider: clusterK8sProvider, dependsOn: [extDnsNs, extDnsRole] }
// );

// for public zone
// const extDns = new k8s.helm.v3.Release(
//   extDnsName,
//   {
//     atomic: false,
//     chart: "external-dns",
//     name: extDnsName,
//     namespace: extDnsName,
//     repositoryOpts: {
//       repo: "https://kubernetes-sigs.github.io/external-dns",
//     },
//     skipCrds: true,
//     values: {
//       aws: {
//         zoneType: "public",
//       },
//       domainFilters: [publicHostedZoneName],
//       policy: "sync",
//       provider: "aws",
//       serviceAccount: {
//         create: false,
//         name: extDnsName,
//       },
//       txtOwnerId: publicHostedZoneId,
//     },
//   },
//   {
//     dependsOn: [extDnsNs, extDnsServiceAccount],
//     provider: clusterK8sProvider,
//   }
// );

// for private zone
// const extDns = new k8s.helm.v3.Release(
//   extDnsName,
//   {
//     atomic: false,
//     chart: "external-dns",
//     name: extDnsName,
//     namespace: extDnsName,
//     repositoryOpts: {
//       repo: "https://kubernetes-sigs.github.io/external-dns",
//     },
//     skipCrds: true,
//     values: {
//       aws: {
//         zoneType: "private",
//       },
//       domainFilters: [privateHostedZoneName],
//       policy: "sync",
//       provider: "aws",
//       serviceAccount: {
//         create: false,
//         name: extDnsName,
//       },
//       txtOwnerId: privateHostedZoneId,
//     },
//   },
//   {
//     dependsOn: [extDnsNs, extDnsServiceAccount],
//     provider: clusterK8sProvider,
//   }
// );

// --- jenkins
// --- https://github.com/jenkinsci/helm-charts

const jenkinsName = "jenkins";

pulumi
  .all([region, caller, userClusterName])
  .apply(([region, caller, userClusterName]) => {
    const jenkinsPolicy = new aws.iam.Policy(jenkinsName, {
      path: `/${userClusterName}-policies/`,
      description: "Jenkins policy",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Effect: "Allow",
            Action: ["ssm:GetParameter"],
            Resource: [
              `arn:aws:ssm:${region.name}:${caller.accountId}:parameter/${userClusterName}*`,
            ],
          },
        ],
      }),
    });
    const jenkinsRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
      jenkinsName,
      {
        policyArn: jenkinsPolicy.arn,
        role: jenkinsRole,
      }
    );
  });

const jenkinsAssumeRolePolicy = pulumi
  .all([clusterOidcProviderUrl, clusterOidcProviderArn])
  .apply(([url, arn]) =>
    aws.iam.getPolicyDocument({
      statements: [
        {
          actions: ["sts:AssumeRoleWithWebIdentity"],
          conditions: [
            {
              test: "StringEquals",
              values: [`system:serviceaccount:${jenkinsName}:${jenkinsName}`],
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

const jenkinsRole = new aws.iam.Role(`${userClusterName}-${jenkinsName}-role`, {
  assumeRolePolicy: jenkinsAssumeRolePolicy.json,
});

const jenkinsNs = new k8s.core.v1.Namespace(
  jenkinsName,
  {
    metadata: { name: jenkinsName },
  },
  { provider: clusterK8sProvider }
);

const jenkinsServiceAccount = new k8s.core.v1.ServiceAccount(
  jenkinsName,
  {
    metadata: {
      namespace: jenkinsName,
      name: jenkinsName,
      annotations: {
        "eks.amazonaws.com/role-arn": jenkinsRole.arn,
      },
    },
  },
  { provider: clusterK8sProvider, dependsOn: [jenkinsNs, jenkinsRole] }
);

const jenkinsDevRole = new k8s.rbac.v1.Role(
  "jenkins-dev-role",
  {
    metadata: {
      name: "jenkins-dev-role",
      namespace: "hopper-dev",
    },
    rules: [
      {
        apiGroups: ["*"],
        resources: ["*"],
        verbs: ["*"],
      },
    ],
  },
  {
    provider: clusterK8sProvider,
  }
);

const jenkinsTestRole = new k8s.rbac.v1.Role(
  "jenkins-test-role",
  {
    metadata: {
      name: "jenkins-test-role",
      namespace: "hopper-test",
    },
    rules: [
      {
        apiGroups: ["*"],
        resources: ["*"],
        verbs: ["*"],
      },
    ],
  },
  {
    provider: clusterK8sProvider,
  }
);

const jenkinsProdRole = new k8s.rbac.v1.Role(
  "jenkins-prod-role",
  {
    metadata: {
      name: "jenkins-prod-role",
      namespace: "hopper-prod",
    },
    rules: [
      {
        apiGroups: ["*"],
        resources: ["*"],
        verbs: ["*"],
      },
    ],
  },
  {
    provider: clusterK8sProvider,
  }
);

const jenkinsDevRoleBinding = new k8s.rbac.v1.RoleBinding(
  "jenkins-dev-role-binding",
  {
    metadata: {
      name: "jenkins-dev-role-binding",
      namespace: "hopper-dev",
    },
    roleRef: {
      apiGroup: "rbac.authorization.k8s.io",
      kind: "Role",
      name: "jenkins-dev-role",
    },
    subjects: [
      {
        kind: "ServiceAccount",
        name: "default",
        namespace: "jenkins",
      },
    ],
  },
  { provider: clusterK8sProvider }
);

const jenkinsTestRoleBinding = new k8s.rbac.v1.RoleBinding(
  "jenkins-test-role-binding",
  {
    metadata: {
      name: "jenkins-test-role-binding",
      namespace: "hopper-test",
    },
    roleRef: {
      apiGroup: "rbac.authorization.k8s.io",
      kind: "Role",
      name: "jenkins-test-role",
    },
    subjects: [
      {
        kind: "ServiceAccount",
        name: "default",
        namespace: "jenkins",
      },
    ],
  },
  { provider: clusterK8sProvider }
);

const jenkinsProdRoleBinding = new k8s.rbac.v1.RoleBinding(
  "jenkins-prod-role-binding",
  {
    metadata: {
      name: "jenkins-prod-role-binding",
      namespace: "hopper-prod",
    },
    roleRef: {
      apiGroup: "rbac.authorization.k8s.io",
      kind: "Role",
      name: "jenkins-prod-role",
    },
    subjects: [
      {
        kind: "ServiceAccount",
        name: "default",
        namespace: "jenkins",
      },
    ],
  },
  { provider: clusterK8sProvider }
);

const jenkinsSaRole = new k8s.rbac.v1.Role(
  "jenkins-sa-role",
  {
    metadata: {
      name: "jenkins-sa-role",
      namespace: "jenkins",
    },
    rules: [
      {
        apiGroups: [""],
        resources: ["secrets"],
        verbs: ["get", "watch", "list"],
      },
    ],
  },
  {
    provider: clusterK8sProvider,
  }
);

const jenkinsSaRoleBinding = new k8s.rbac.v1.RoleBinding(
  "jenkins-sa-role-binding",
  {
    metadata: {
      name: "jenkins-sa-role-binding",
      namespace: "jenkins",
    },
    roleRef: {
      apiGroup: "rbac.authorization.k8s.io",
      kind: "Role",
      name: "jenkins-sa-role",
    },
    subjects: [
      {
        kind: "ServiceAccount",
        name: "jenkins",
        namespace: "jenkins",
      },
      {
        kind: "ServiceAccount",
        name: "default",
        namespace: "jenkins",
      },
    ],
  },
  { provider: clusterK8sProvider }
);

const jenkins = new k8s.helm.v3.Release(
  jenkinsName,
  {
    name: jenkinsName,
    namespace: jenkinsName,
    chart: "./charts/jenkins",

    values: {
      serviceAccount: {
        create: false,
        name: jenkinsName,
      },
      controller: {
        // ingress: {
        //   enabled: true,
        //   apiVersion: "networking.k8s.io/v1",
        //   annotations: {
        //     "kubernetes.io/tls-acme": "true",
        //     "external-dns.alpha.kubernetes.io/hostname": `jenkins.${clusterDomain}`,
        //   },
        //   ingressClassName: "alb",
        //   hostName: `jenkins.${clusterDomain}`,
        // },
        // secondaryingress: {
        //   enabled: true,
        //   apiVersion: "networking.k8s.io/v1",
        //   annotations: {
        //     "kubernetes.io/ingress.class": "public",
        //     "kubernetes.io/tls-acme": "true",
        //     "external-dns.alpha.kubernetes.io/hostname": `jenkins-scm.${clusterDomain}`,
        //   },
        //   ingressClassName: "alb",
        //   hostName: `jenkins-scm.${clusterDomain}`,
        //   paths: [
        //     "/github-webhook"
        //   ],
        // },
        installPlugins: [
          "amazon-ecr",
          "blueocean",
          "configuration-as-code",
          "configuration-as-code-secret-ssm",
          "git",
          "github-autostatus",
          "job-dsl",
          "kubernetes",
          "kubernetes-cli",
          "kubernetes-credentials-provider",
          "sonar",
          "sse-gateway",
          "strict-crumb-issuer",
          "warnings-ng",
          "workflow-aggregator",
        ],
        jenkinsUrl: `https://jenkins.${clusterDomain}`,
        JCasC: {
          configScripts: {
            ["welcome-message"]: `
              jenkins:
                systemMessage: Welcome to Hopper Jenkins
            `,
            // ["seeder"]: `
            //   jobs:
            //     - script: >
            //         pipelineJob('seeder') {
            //           definition {
            //             cpsScm {
            //               scm {
            //                 git {
            //                   remote {
            //                     branch('main')
            //                     url('${seedJobRepositoryHttpsUrl}')
            //                     credentials('github-creds')
            //                   }
            //                 }
            //               }
            //               steps {
            //                 jobDsl {
            //                   targets '${seedJobGroovyFilePath}/*.groovy'
            //                 }
            //               }
            //             }
            //           }
            //         }
            // `
          },
        },
        // serviceType: "LoadBalancer",
        // serviceAnnotations: {
        //   "external-dns.alpha.kubernetes.io/hostname": `jenkins.${clusterDomain}`,
        // },
      },
    },
  },
  {
    dependsOn: [ebsCsiDriver],
    provider: clusterK8sProvider,
  }
);

// --- sonarqube
// --- https://github.com/SonarSource/helm-chart-sonarqube

const sonarqubeName = "sonarqube";

// TODO why does sq need to change R53?
// const sonarqubePolicy = new aws.iam.Policy(sonarqubeName, {
//   path: `/${userClusterName}-policies/`,
//   description: "sonarqube policy",
//   policy: JSON.stringify({
//     Version: "2012-10-17",
//     Statement: [
//       {
//         Effect: "Allow",
//         Action: ["route53:ChangeResourceRecordSets"],
//         Resource: [`arn:aws:route53:::hostedzone/${publicHostedZoneId}`],
//       },
//       {
//         Effect: "Allow",
//         Action: ["route53:ListHostedZones", "route53:ListResourceRecordSets"],
//         Resource: ["*"],
//       },
//     ],
//   }),
// });

const sonarqubeAssumeRolePolicy = pulumi
  .all([clusterOidcProviderUrl, clusterOidcProviderArn])
  .apply(([url, arn]) =>
    aws.iam.getPolicyDocument({
      statements: [
        {
          actions: ["sts:AssumeRoleWithWebIdentity"],
          conditions: [
            {
              test: "StringEquals",
              values: [`system:serviceaccount:${sonarqubeName}:${sonarqubeName}`],
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

const sonarqubeRole = new aws.iam.Role(`${userClusterName}-${sonarqubeName}-role`, {
  name: `${userClusterName}-${sonarqubeName}`,
  assumeRolePolicy: sonarqubeAssumeRolePolicy.json,
});

// const sonarqubeRolePolicyAttachment = new aws.iam.RolePolicyAttachment(
//   sonarqubeName,
//   {
//     policyArn: sonarqubePolicy.arn,
//     role: sonarqubeRole,
//   }
// );

const sonarqubeNs = new k8s.core.v1.Namespace(
  sonarqubeName,
  {
    metadata: { name: sonarqubeName },
  },
  { provider: clusterK8sProvider }
);

const sonarqubeServiceAccount = new k8s.core.v1.ServiceAccount(
  sonarqubeName,
  {
    metadata: {
      namespace: sonarqubeName,
      name: sonarqubeName,
      annotations: {
        "eks.amazonaws.com/role-arn": sonarqubeRole.arn,
      },
    },
  },
  { provider: clusterK8sProvider, dependsOn: [sonarqubeNs, sonarqubeRole] }
);

const sonarqube = new k8s.helm.v3.Release(
  sonarqubeName,
  {
    name: sonarqubeName,
    namespace: sonarqubeName,
    chart: "./charts/sonarqube",
    values: {
      // serviceAccount: {
      //   create: false,
      //   name: sonarqubeServiceAccount,
      // },
      readinessProbe: {
        timeout: 60
      },
      startupProbe: {
        timeout: 60
      },
    }
    // values: {
    //   service: {
    //     type: "ClusterIP",
    //     annotations: {
    //       "external-dns.alpha.kubernetes.io/hostname": `sonarqube.${clusterDomain}`,
    //     },
    //   },
    // },
  },
  {
    dependsOn: [sonarqubeNs],
    provider: clusterK8sProvider,
  }
);

// --- k8s dashboard
// --- https://github.com/kubernetes/dashboard

const k8sDashName = "k8s-dash";

const k8sDashPolicy = new aws.iam.Policy(k8sDashName, {
  path: `/${userClusterName}-policies/`,
  description: "k8sDash policy",
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: ["route53:ChangeResourceRecordSets"],
        Resource: [`arn:aws:route53:::hostedzone/${publicHostedZoneId}`],
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
const k8sDashServiceAccountClusterRoleBinding = new k8s.rbac.v1.ClusterRoleBinding(
  k8sDashName,
  {
    metadata: {
      name: k8sDashName
    },
    roleRef: {
      apiGroup: "rbac.authorization.k8s.io",
      kind: "ClusterRole",
      name: "cluster-admin"
    },
    subjects: [
      {
        kind: "ServiceAccount",
        name: k8sDashName,
        namespace: k8sDashName
      }
    ]
  },
  { provider: clusterK8sProvider, dependsOn: [k8sDashNs] }
)

const k8sDashServiceAccountToken = new k8s.core.v1.Secret(
  k8sDashName, {
  metadata: {
    namespace: k8sDashName,
    name: k8sDashName,
    annotations: {
      "kubernetes.io/service-account.name": k8sDashName
    }
  },
  type: "kubernetes.io/service-account-token"
},
  { provider: clusterK8sProvider, dependsOn: [k8sDashServiceAccount], }
)

const k8sDash = new k8s.helm.v3.Release(
  k8sDashName,
  {
    name: k8sDashName,
    namespace: k8sDashName,
    chart: "./charts/kubernetes-dashboard",
    values: {
      "cert-manager": {
        enabled: false
      },
      nginx: {
        enabled: false
      },
      serviceAccount: {
        create: false,
        name: k8sDashName
      },
    },
  },
  {
    dependsOn: [k8sDashNs, awsLbc, certManager],
    provider: clusterK8sProvider
  }
);

// --- argocd
// --- https://github.com/argoproj/argo-helm

const argoName = "argocd";

const argoNs = new k8s.core.v1.Namespace(
  argoName,
  {
    metadata: { name: argoName },
  },
  { provider: clusterK8sProvider }
);

const argoCrdTemplates = fs.readdirSync("./charts/argo-cd/templates/crds");
const argoCrdFileNames = new Array<string>();

argoCrdTemplates.map((filename) => {
  argoCrdFileNames.push(filename);
});

const argoCrds = new k8s.yaml.ConfigGroup(`${argoName}-crds`,
  {
    files: argoCrdFileNames
  },
  {
    provider: clusterK8sProvider,
    dependsOn: [argoNs]
  });

const argo = new k8s.helm.v3.Release(
  argoName,
  {
    name: argoName,
    namespace: argoName,
    chart: "./charts/argo-cd",
    // values: {
    //   server: {
    //     service: {
    //       type: "ClusterIP",
    //       annotations: {
    //         "external-dns.alpha.kubernetes.io/hostname": `argocd.${clusterDomain}`,
    //       },
    //     },
    //   },
    // },
  },
  {
    //dependsOn: [argoNs, argoCrds[crdsFileNames.length - 1]],
    dependsOn: [argoNs, argoCrds],
    provider: clusterK8sProvider,
  }
);

// --- keycloak
// --- https://bitnami.com/stack/keycloak/helm

const keycloakName = "keycloak";

const keycloakNs = new k8s.core.v1.Namespace(
  keycloakName,
  {
    metadata: { name: keycloakName },
  },
  { provider: clusterK8sProvider }
);

const keycloak = new k8s.helm.v3.Release(
  keycloakName,
  {
    name: keycloakName,
    namespace: keycloakName,
    chart: "./charts/keycloak",
    values: {
      commands: [
        "/opt/keycloak/bin/kc.sh",
        "start",
        "--http-enabled=true",
        "--http-port=8080",
        "--hostname-strict=false",
        "--hostname-strict-https=false"
      ],
      extraEnv: "- name: KEYCLOAK_ADMIN\n  value: admin\n- name: KEYCLOAK_ADMIN_PASSWORD\n  value: admin\n- name: JAVA_OPTS_APPEND\n  value: >-\n    -Djgroups.dns.query={{ include \"keycloak.fullname\" . }}-headless\n"
    },
  },
  {
    dependsOn: [keycloakNs],
    provider: clusterK8sProvider,
  }
);

// --- smtp4dev

const smtpName = "smtp4dev";

const smtpNs = new k8s.core.v1.Namespace(
  smtpName,
  {
    metadata: { name: smtpName },
  },
  { provider: clusterK8sProvider }
);

const smtpDeployment = new k8s.apps.v1.Deployment(smtpName,
  {
    apiVersion: "apps/v1",
    kind: "Deployment",
    metadata: {
      name: smtpName,
      namespace: smtpName,
      labels: {
        app: smtpName
      }
    },
    spec: {
      replicas: 1,
      selector: {
        matchLabels: {
          app: smtpName
        }
      },
      template: {
        metadata: {
          labels: {
            app: smtpName
          }
        }, spec: {
          containers: [
            {
              name: smtpName,
              image: "rnwood/smtp4dev:latest",
              ports: [
                { containerPort: 80 }, { containerPort: 25 }
              ]
            }
          ]
        }
      }
    },
  },
  {
    dependsOn: [smtpNs]
  });

const smtpService = new k8s.core.v1.Service(smtpName,
  {
    apiVersion: "v1",
    kind: "Service",
    metadata: {
      name: smtpName,
      namespace: smtpName
    },
    spec: {
      selector: {
        app: smtpName
      },
      ports: [
        {
          name: "smtp",
          protocol: "TCP",
          port: 25,
          targetPort: 25
        },
        {
          name: "http",
          protocol: "TCP",
          port: 80,
          targetPort: 80
        }
      ]
    }
  },
  {
    dependsOn: [smtpNs]
  });

// --- postgres (in-cluster)
// --- https://github.com/bitnami/charts/tree/main/bitnami/postgresql

// TODO: add postgres for each environment (namespace)
// use in-cluster for tech challenges; RDS for other (create in 20-aws-services stack)
