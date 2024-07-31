import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

import { config } from "./config";

const KARPENTER = "karpenter";
const namespace = "kube-system";
const region = aws.getRegion();
const identity = aws.getCallerIdentity();
const clusterName = config.clusterName;
const cluster = aws.eks.getCluster({ name: clusterName });

const clusterOidcProviderUrl = config.clusterOidcProviderUrl;
const clusterOidcProviderArn = pulumi
  .all([
    identity.then(i => i.accountId),
    clusterOidcProviderUrl,
  ])
  .apply(([accountId, url]) => {
    return `arn:aws:iam::${accountId}:oidc-provider/${url}`;
  });

const policyArns = [
  { name: "AmazonEBSCSIDriverPolicy", path: "policy/service-role" },
  { name: "AmazonEC2ContainerRegistryReadOnly", path: "policy" },
  { name: "AmazonEKS_CNI_Policy", path: "policy" },
  { name: "AmazonEKSWorkerNodePolicy", path: "policy" },
  { name: "AmazonSSMManagedInstanceCore", path: "policy" },
  { name: "CloudWatchAgentServerPolicy", path: "policy" },
  { name: "AWSXrayWriteOnlyAccess", path: "policy" },
];

const nodeRole = new aws.iam.Role(
  `${KARPENTER}-node-role`,
  {
    name: `KarpenterNodeRole-${clusterName}`,
    assumeRolePolicy: {
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Principal: {
            Service: "ec2.amazonaws.com"
          },
          Action: "sts:AssumeRole"
        }
      ]
    },
  },
);

const nodeRolePolicyAttachments = policyArns.map(arn => {
  return new aws.iam.RolePolicyAttachment(
    `${KARPENTER}-node-role-attach-${arn.name}`,
    {
      role: nodeRole.name,
      policyArn: `arn:aws:iam::aws:${arn.path}/${arn.name}`,
    },
    { dependsOn: [nodeRole] }
  );
});

pulumi.all([
  config.publicSubnetIds,
  config.privateSubnetIds,
])
.apply(([
  publicSubnetIds,
  privateSubnetIds,
]) => {
  return new aws.eks.NodeGroup(
    `${clusterName}-ng`,
    {
      clusterName,
      instanceTypes: ["m6i.xlarge"],
      nodeGroupName: `${clusterName}-ng`,
      nodeRoleArn: nodeRole.arn,
      subnetIds: [
        ...publicSubnetIds,
        ...privateSubnetIds
      ],
      scalingConfig: {
        desiredSize: 3,
        maxSize: 5,
        minSize: 3,
      },
    },
    { dependsOn: nodeRolePolicyAttachments }
  );
})

const controllerPolicy = pulumi
  .all([
    region.then(r => r.name),
    identity.then(i => i.accountId),
  ])
  .apply(([region, accountId]) => {

    const requestTags = JSON.parse(`{
      "aws:RequestTag/kubernetes.io/cluster/${clusterName}": "owned",
      "aws:RequestTag/topology.kubernetes.io/region": "${region}"
    }`);
    
    const resourceTags = JSON.parse(`{
      "aws:ResourceTag/kubernetes.io/cluster/${clusterName}": "owned",
      "aws:ResourceTag/topology.kubernetes.io/region": "${region}"
    }`);

    return new aws.iam.Policy(
      `${KARPENTER}-controller-policy`,
      {
        name: `KarpenterControllerPolicy-${clusterName}`,
        path: `/${clusterName}-policies/`,
        description: "Karpenter Controller policy",
        policy: JSON.stringify({
          Version: "2012-10-17",
          Statement: [
            {
              Sid: "Karpenter",
              Effect: "Allow",
              Action: [
                "ssm:GetParameter",
                "ec2:DescribeImages",
                "ec2:RunInstances",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeAvailabilityZones",
                "ec2:DeleteLaunchTemplate",
                "ec2:CreateTags",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateFleet",
                "ec2:DescribeSpotPriceHistory",
                "pricing:GetProducts"
              ],
              Resource: "*",
            },
            {
              Sid: "ConditionalEC2Termination",
              Effect: "Allow",
              Action: "ec2:TerminateInstances",
              Condition: {
                StringLike: {
                  "ec2:ResourceTag/karpenter.sh/nodepool": "*"
                }
              },
              Resource: "*",
            },
            {
              Sid: "PassNodeIAMRole",
              Effect: "Allow",
              Action: "iam:PassRole",
              Resource: `arn:aws:iam::${accountId}:role/KarpenterNodeRole-${clusterName}`,
            },
            {
              Sid: "EKSClusterEndpointLookup",
              Effect: "Allow",
              Action: "eks:DescribeCluster",
              Resource: `arn:aws:eks:${region}:${accountId}:cluster/${clusterName}`,
            },
            {
              Sid: "AllowScopedInstanceProfileCreationActions",
              Effect: "Allow",
              Action: ["iam:CreateInstanceProfile"],
              Resource: "*",
              Condition: {
                StringEquals: { ...requestTags },
                StringLike: {
                  "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
              }
            },
            {
              Sid: "AllowScopedInstanceProfileTagActions",
              Effect: "Allow",
              Action: ["iam:TagInstanceProfile"],
              Resource: "*",
              Condition: {
                StringEquals: {
                  ...resourceTags,
                  ...requestTags,
                },
                StringLike: {
                  "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*",
                  "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
              }
            },
            {
              Sid: "AllowScopedInstanceProfileActions",
              Effect: "Allow",
              Action: [
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteInstanceProfile"
              ],
              Resource: "*",
              Condition: {
                StringEquals: { ...resourceTags },
                StringLike: {
                  "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
                }
              }
            },
            {
              Sid: "AllowInstanceProfileReadActions",
              Effect: "Allow",
              Action: "iam:GetInstanceProfile",
              Resource: "*"
            }
          ]
        })
      }
    );
  });

const controllerRole = pulumi
  .all([
    clusterOidcProviderUrl,
    clusterOidcProviderArn,
  ])
  .apply(([url, arn]) => {
    return new aws.iam.Role(
      `${KARPENTER}-controller-role`,
      {
        name: `KarpenterControllerRole-${clusterName}`,
        assumeRolePolicy: {
          Version: "2012-10-17",
          Statement: [
            {
              Effect: "Allow",
              Principal: {
                Federated: arn,
              },
              Action: "sts:AssumeRoleWithWebIdentity",
              Condition: {
                StringEquals: JSON.parse(`{
                  "${url}:aud": "sts.amazonaws.com",
                  "${url}:sub": "system:serviceaccount:${namespace}:${KARPENTER}"
                }`)
              }
            }
          ]
        }
      }
    );
  });

new aws.iam.RolePolicyAttachment(
  `${KARPENTER}-controller-role-policy-attachment`,
  {
    policyArn: controllerPolicy.arn,
    role: controllerRole.name,
  },
  { dependsOn: [controllerPolicy, controllerRole] }
);

pulumi.all([
  cluster.then(c => c.vpcConfig)
])
.apply(([vpcConfig]) => {
  vpcConfig.subnetIds.forEach(subnetId => {
    new aws.ec2.Tag(
      `tag-subnet-${subnetId}`,
      {
        key: "karpenter.sh/discovery",
        value: clusterName,
        resourceId: subnetId,
      }
    );
  });

  new aws.ec2.Tag(
    `tag-security-group-${vpcConfig.clusterSecurityGroupId}`,
    {
      key: "karpenter.sh/discovery",
      value: clusterName,
      resourceId: vpcConfig.clusterSecurityGroupId,
    }
  );
});
