import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

const config = new pulumi.Config();
const userClusterName = process.env.CLUSTER_NAME;
const clusterDomain = process.env.CLUSTER_DOMAIN;

// create secure string parameters in Systems Manager for all secrets/important data
// const paramAwsKey = new aws.ssm.Parameter(`${userClusterName}-aws-key`, {
//   type: "SecureString",
//   value: config.requireSecret("aws_access_key_id"),

// });

// const paramAwsSecret = new aws.ssm.Parameter(`${userClusterName}-aws-secret`, {
//   type: "SecureString",
//   value: config.requireSecret("aws_secret_access_key"),
// });

const paramGithubUser = new aws.ssm.Parameter(
  `${userClusterName}-github-user`,
  {
    name: `/${userClusterName}/github-username`,
    type: "SecureString",
    value: config.requireSecret("github_user"),
  }
);

export const githubUser = config.requireSecret("github_user");

const paramGithubPat = new aws.ssm.Parameter(`${userClusterName}-github-pat`, {
  name: `/${userClusterName}/github-pat`,
  type: "SecureString",
  value: config.requireSecret("github_pat"),
});

export const githubPat = config.requireSecret("github_pat");

export const teamsChannelUrl = config.requireSecret("teams_channel_url");

const paramClusterName = new aws.ssm.Parameter(
  `${userClusterName}-cluster-name`,
  {
    name: `/${userClusterName}/cluster-name`,
    type: "String",
    value: config.require("cluster_name"),
  }
);

const paramClusterDomain = new aws.ssm.Parameter(
  `${userClusterName}-cluster-domain`,
  {
    name: `/${userClusterName}/cluster-domain`,
    type: "String",
    value: config.require("cluster_domain"),
  }
);

// export const paramAwsKeyName = paramAwsKey.name;
// export const paramAwsSecretName = paramAwsSecret.name;
export const paramGithubUserName = paramGithubUser.name;
export const paramGithubPatName = paramGithubPat.name;

// managed policies EKS requires for nodegroups
const nodegroupManagedPolicyArns: string[] = [
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
  "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
];

// create the EKS cluster admins role
const adminsName = "admins";
const adminsIamRole = new aws.iam.Role(
  `${userClusterName}-eks-cluster-${adminsName}-role`,
  {
    assumeRolePolicy: aws.getCallerIdentity().then((id) =>
      aws.iam.assumeRolePolicyForPrincipal({
        AWS: `arn:aws:iam::${id.accountId}:root`,
      })
    ),
  }
);

export const adminsIamRoleArn = adminsIamRole.arn;
const adminsIamRolePolicy = new aws.iam.RolePolicy(
  `${userClusterName}-eks-cluster-${adminsName}-policy`,
  {
    role: adminsIamRole,
    policy: {
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: ["eks:*", "ec2:DescribeImages"],
          Resource: "*",
        },
        { Effect: "Allow", Action: "iam:PassRole", Resource: "*" },
      ],
    },
  },
  { parent: adminsIamRole }
);

// create the EKS cluster developers role
const devName = "devs";
const devsIamRole = new aws.iam.Role(
  `${userClusterName}-eks-cluster-${devName}-role`,
  {
    assumeRolePolicy: aws.getCallerIdentity().then((id) =>
      aws.iam.assumeRolePolicyForPrincipal({
        AWS: `arn:aws:iam::${id.accountId}:root`,
      })
    ),
  }
);
export const devsIamRoleArn = devsIamRole.arn;

// create the standard node group worker role and attach the required policies
const stdName = "standardNodeGroup";
const stdNodegroupIamRole = new aws.iam.Role(
  `${userClusterName}-eks-cluster-${stdName}-role`,
  {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
      Service: "ec2.amazonaws.com",
    }),
  }
);

attachPoliciesToRole(stdName, stdNodegroupIamRole, nodegroupManagedPolicyArns);
export const stdNodegroupIamRoleArn = stdNodegroupIamRole.arn;

// create the performance node group worker role and attach the required policies
const perfName = "performanceNodeGroup";
const perfNodegroupIamRole = new aws.iam.Role(
  `${userClusterName}-eks-cluster-${perfName}-role`,
  {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
      Service: "ec2.amazonaws.com",
    }),
  }
);

attachPoliciesToRole(
  perfName,
  perfNodegroupIamRole,
  nodegroupManagedPolicyArns
);
export const perfNodegroupIamRoleArn = perfNodegroupIamRole.arn;

function attachPoliciesToRole(
  name: string,
  role: aws.iam.Role,
  policyArns: string[]
) {
  for (const policyArn of policyArns) {
    new aws.iam.RolePolicyAttachment(`${name}-${policyArn.split("/")[1]}`, {
      policyArn: policyArn,
      role: role,
    });
  }
}
