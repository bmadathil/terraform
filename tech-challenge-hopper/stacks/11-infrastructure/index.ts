import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as awsx from "@pulumi/awsx";

const userClusterName = process.env.CLUSTER_NAME;
const clusterDomain = process.env.CLUSTER_DOMAIN;
export const clusterOwnedTag = {
  [`kubernetes.io/cluster/${userClusterName}`]: "owned",
};

const privateElbTag = { "kubernetes.io/role/internal-elb": "1" };
const publicElbTag = { "kubernetes.io/role/elb": "1" };

// TODO: externalize
const numAzs = 2;
const availableAzs = aws.getAvailabilityZones({
  state: "available",
});

const azs = await availableAzs.then((azs) => azs.zoneIds);

let vpcPrivateSubnets: awsx.classic.ec2.VpcSubnetArgs[] = [];
let vpcPublicSubnets: awsx.classic.ec2.VpcSubnetArgs[] = [];

// define private subnets
for (let i = 0; i < numAzs; i++) {
  vpcPrivateSubnets.push({
    type: "private",
    name: `${userClusterName}-private-${i}`,
    location: {
      cidrBlock: `172.16.${i * 16 + 16}.0/20`,
      availabilityZoneId: azs[i],
    },
    tags: { ...clusterOwnedTag, ...privateElbTag },
  });
}

// define public subnets
for (let i = 0; i < numAzs; i++) {
  vpcPublicSubnets.push({
    type: "public",
    name: `${userClusterName}-public-${i}`,
    location: {
      cidrBlock: `172.16.${i * 16 + 64}.0/20`,
      availabilityZoneId: azs[i],
    },
    tags: { ...clusterOwnedTag, ...publicElbTag },
  });
}

// create vpc
const vpcName = `${userClusterName}-vpc`;
const vpc = new awsx.classic.ec2.Vpc(vpcName, {
  cidrBlock: "172.16.0.0/16",
  numberOfAvailabilityZones: numAzs,
  enableDnsHostnames: true,
  enableDnsSupport: true,
  subnets: [...vpcPrivateSubnets, ...vpcPublicSubnets],
  tags: {
    Name: vpcName,
    Usage: "hopper",
    ClusterName: `${userClusterName}`,
  },
});

// --- dns
// TODO: need to change env vars for better separation of cluster name and TLD, which can then be used here
// TODO: temp remove public zone
// const sandboxPublicZone = aws.route53.getZone({ name: "sandbox.cvpcorp.io." });

// create a public zone
// const hopperPublicZone = new aws.route53.Zone("hopper-public-zone", {
//   name: `${clusterDomain}`,
//   forceDestroy: true,
// });

// create a private zone
// TODO: change to "privateZone" and name with cluster name
const hopperPrivateZone = new aws.route53.Zone("hopper-private-zone", {
  name: `${clusterDomain}`,
  vpcs: [{ vpcId: vpc.id }],
  forceDestroy: true,
});

// TODO: make more friendly; this only works if there is a public zone available for use,
// which likely means in an environment we have full control over and not e.g., a tech challenge env

// add the public zone NS records to the sandbox public zone for delegation
// const hopperPublicZoneNs = new aws.route53.Record("hopper-public-ns", {
//   zoneId: sandboxPublicZone.then(zone => zone.zoneId),
//   name: `${clusterDomain}`,
//   type: "NS",
//   ttl: 30,
//   records: hopperPublicZone.nameServers
// });

// --- s3 for data files
//const bucket = new aws.s3.BucketV2("data-bucket", {
//  bucket: `${userClusterName}-data-bucket`,
//  forceDestroy: true,
//});

//const bucketAcl = new aws.s3.BucketAclV2("data-bucket-acl", {
//  acl: "public-read",
//  bucket: bucket.id,
//});

export const vpcId = vpc.id;
export const publicSubnetIds = vpc.publicSubnetIds;
export const privateSubnetIds = vpc.privateSubnetIds;
export const azsUsed = azs;
// export const publicHostedZoneName = hopperPublicZone.name;
// export const publicHostedZoneId = hopperPublicZone.zoneId;
export const privateHostedZoneName = hopperPrivateZone.name;
export const privateHostedZoneId = hopperPrivateZone.zoneId;
//export const dataBucketUrl = bucket.bucketDomainName;
//export const dataBucketArn = bucket.arn;
