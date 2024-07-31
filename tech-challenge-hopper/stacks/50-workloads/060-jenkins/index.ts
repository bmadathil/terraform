import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

import { config } from "./config";
import { ExternalSecret } from "../interfaces";
import { getClusterConfig } from "../cluster-config";
import { createExternalSecret, retrieveCredentials } from "./functions";

interface Workload {
  name: string;
  host: string;
  title: string;
  imageTag: string;
  tagLabel: string;
  seedFolder: string;
  roleNamespaces: string[];
  secrets: ExternalSecret[];
  adminCredentials: ExternalSecret;
}

const JENKINS = "jenkins";
const region = aws.getRegion();
const clusterName = config.clusterName;
const identity = aws.getCallerIdentity();
const clusterOidcProviderUrl = config.clusterOidcProviderUrl;

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

const clusterOidcProviderArn = pulumi
  .all([
    identity.then(i => i.accountId),
    clusterOidcProviderUrl,
  ])
  .apply(([ accountId, url ]) => {
    return `arn:aws:iam::${accountId}:oidc-provider/${url}`;
  });

const jenkinsPolicy = pulumi
  .all([
    region.then(r => r.name),
    identity.then(i => i.accountId),
  ])
  .apply(([ region, accountId ]) => {
    return new aws.iam.Policy(
      `${JENKINS}-policy`,
      {
        path: `/${clusterName}-policies/`,
        description: "Jenkins policy",
        policy: JSON.stringify({
          Version: "2012-10-17",
          Statement: [
            {
              Effect: "Allow",
              Action: ["ssm:GetParameter"],
              Resource: [
                `arn:aws:ssm:${region}:${accountId}:parameter/*`,
              ],
            },
          ],
        }),
      }
    );
});

async function execute() {
  
  const clusterConfig = await getClusterConfig();
 
  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;
    const key = `${namespace}-${JENKINS}`;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === JENKINS
    );

    if (workload) {

      const jenkinsAssumeRolePolicy = pulumi
        .all([
          clusterOidcProviderUrl,
          clusterOidcProviderArn,
        ])
        .apply(([ url, arn ]) => {
          return aws.iam.getPolicyDocument({
            statements: [
              {
                actions: ["sts:AssumeRoleWithWebIdentity"],
                conditions: [
                  {
                    test: "StringEquals",
                    values: [`system:serviceaccount:${JENKINS}:${namespace}`],
                    variable: `${url}:sub`,
                  },
                  {
                    test: "StringEquals",
                    values: ["sts.amazonaws.com"],
                    variable: `${url}:aud`,
                  },
                ],
                effect: "Allow",
                principals: [
                  {
                    identifiers: [arn],
                    type: "Federated"
                  }
                ],
              },
            ],
          })
        });

      const jenkinsRole = new aws.iam.Role(
        `${key}-role`,
        { assumeRolePolicy: jenkinsAssumeRolePolicy.json }
      );      

      new aws.iam.RolePolicyAttachment(
        `${key}-role-policy-attachment`,
        {
          policyArn: jenkinsPolicy.arn,
          role: jenkinsRole,
        }
      );

      const jenkinsServiceAccount = new k8s.core.v1.ServiceAccount(
        `${key}-sa`,
        {
          metadata: {
            name: JENKINS,
            namespace,
            annotations: {
              "eks.amazonaws.com/role-arn": jenkinsRole.arn,
            },
          },
        },
        {
          dependsOn: [jenkinsRole],
          provider: clusterK8sProvider
        }
      );

      const saRole = new k8s.rbac.v1.Role(
        `${key}-sa-role`,
        {
          metadata: {
            name: `${JENKINS}-sa-role`,
            namespace,
          },
          rules: [
            {
              apiGroups: [""],
              resources: ["secrets"],
              verbs: ["get", "watch", "list"],
            },
          ],
        },
        { provider: clusterK8sProvider }
      );

      new k8s.rbac.v1.RoleBinding(
        `${key}-sa-role-binding`,
        {
          metadata: {
            name: `${JENKINS}-sa-role-binding`,
            namespace,
          },
          roleRef: {
            apiGroup: "rbac.authorization.k8s.io",
            kind: "Role",
            name: saRole.metadata.name,
          },
          subjects: [
            {
              kind: "ServiceAccount",
              name: JENKINS,
              namespace,
            },
            {
              kind: "ServiceAccount",
              name: "default",
              namespace,
            },
          ],
        },
        {
          dependsOn: [saRole],
          provider: clusterK8sProvider
        }
      );

      new k8s.core.v1.Secret(
        `${key}-github-credentials`,
        {
          metadata: {
            name: "github-credentials",
            namespace,
            annotations: {
              "jenkins.io/credentials-description":
              "GitHub username/PAT with repo and registry access",
            },
            labels: {
              "jenkins.io/credentials-type": "usernamePassword",
            },
          },
          type: "Opaque",
          stringData: {
            username: config.githubUser,
            password: config.githubPat,
          },
        }
      );

      new k8s.core.v1.Secret(
        `${key}-github-token`,
        {
          metadata: {
            name: "github-token",
            namespace,
            annotations: {
              "jenkins.io/credentials-description":
              `GitHub PAT (from user: ${config.githubUser}) with admin:repo_hook, repo, and repo:status permissions`,
            },
            labels: {
              "jenkins.io/credentials-type": "secretText",
            },
          },
          type: "Opaque",
          stringData: {
            text: config.githubPat,
          },
        }
      );

      pulumi
        .all([ config.kubeconfig ])
        .apply(([ kubeconfig ]) => {
          return new k8s.core.v1.Secret(
            `${key}-kubeconfig`,
            {
              metadata: {
                name: "kubeconfig",
                namespace,
                annotations: {
                  "jenkins.io/credentials-description": "Cluster kubeconfig",
                },
                labels: {
                  "jenkins.io/credentials-type": "secretText",
                },
              },
              type: "Opaque",
              stringData: {
                text: kubeconfig,
              },
            }
          );
        });

      const adminSecret = await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );
      
      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials
      );

      workload.secrets.forEach(secret => {
        createExternalSecret(
          namespace, secret, clusterK8sProvider
        );
      });

      new k8s.helm.v3.Release(
        `${key}-release`,
        {
          name: JENKINS,
          namespace,
          chart: "./jenkins",
          values: {
            serviceAccount: {
              name: JENKINS,
              create: false,
            },
            controller: {
              image: "ghcr.io/cvpcorp/jenkins",
              tag: workload.imageTag,
              tagLabel: workload.tagLabel,
              imagePullSecretName: "ghcr-pull-secret",
              installPlugins: false,
              admin: {
                existingSecret: workload.adminCredentials.name,
                userKey: adminCredentials.userSecretKey,
                passwordKey: adminCredentials.passwordSecretKey,
              },
              persistence: {
                size: "50Gi",
              },
              JCasC: {
                security: {
                  globalJobDslSecurityConfiguration: {
                    useScriptSecurity: false,
                  },
                },
                configScripts: {
                  ["welcome-message"]: `
                    jenkins:
                      systemMessage: Jenkins CI/CD application pipeline management.`,
                  ["github"]: `
                    unclassified:
                      gitHubPluginConfig:
                        configs:
                        - credentialsId: "github-token"
                          name: "GitHub"
                        hookUrl: "http://localhost:8080/github-webhook/"`,
                  ["sonarqube"]: `
                    unclassified:
                      sonarGlobalConfiguration:
                        buildWrapperEnabled: true
                        installations:
                        - credentialsId: "sonarqube-jenkins-token"
                          name: "sonarqube"
                          serverUrl: "http://sonarqube.${namespace}.svc.cluster.local:9000"
                          triggers:
                            envVar: "SKIP_SQ"
                            skipScmCause: false
                            skipUpstreamCause: false`,
                  ["sonarscanner"]: `
                    tool:
                      sonarRunnerInstallation:
                        installations:
                        - name: "sonarscanner"
                          properties:
                          - installSource:
                              installers:
                              - sonarRunnerInstaller:
                                  id: "6.0.0.4432"`,
                  ["nodejs"]: `
                    tool:
                      nodejs:
                        installations:
                        - name: "nodejs"
                          properties:
                          - installSource:
                              installers:
                              - nodejsInstaller:
                                  id: "20.10.0"`,
                  ["build-monitor"]: `
                    jenkins:
                      primaryView:
                        buildMonitor:
                          name: "bm-all"
                      views:
                      - buildMonitor:
                          config:
                            colourBlindMode: true
                            displayBadges: "Always"
                            displayBadgesFrom: "getLastBuild"
                            maxColumns: 4
                            order: "byName"
                            textScale: "0.5"
                          includeRegex: "(?!seeder).*"
                          name: "bm-all"
                          recurse: true
                          title: "${workload.title}"
                    unclassified:
                      buildMonitorView:
                        permissionToCollectAnonymousUsageStatistics: true`,
                  ["seeder"]: `
                    jobs:
                      - script: >
                          job('seeder') {
                            authenticationToken('h4r-jenkins-seed')
                            scm {
                              git {
                                remote {
                                  branch('main')
                                  url('${config.seedJobRepoUrl}')
                                  credentials('github-credentials')
                                }
                              }
                            }
                            steps {
                              jobDsl {
                                targets '${workload.seedFolder}/**/*.groovy'
                              }
                            }
                          }`,
                },
              },
            },
          },
        },
        {
          dependsOn: [jenkinsServiceAccount,adminSecret],
          provider: clusterK8sProvider,
        }
      );

      new k8s.apiextensions.CustomResource(
        `${key}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: JENKINS,
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
                    name: JENKINS,
                    kind: "Service",
                    namespace,
                    port: 8080,
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

      workload.roleNamespaces.forEach(rns => {

        const role = new k8s.rbac.v1.Role(
          `${rns}-${JENKINS}-role`,
          {
            metadata: {
              name: `${JENKINS}-role`,
              namespace: rns,
            },
            rules: [
              {
                apiGroups: ["*"],
                resources: ["*"],
                verbs: ["*"],
              },
            ],
          },
          { provider: clusterK8sProvider }
        );
  
        new k8s.rbac.v1.RoleBinding(
          `${rns}-${JENKINS}-role-binding`,
          {
            metadata: {
              name: `${JENKINS}-role-binding`,
              namespace: rns,
            },
            roleRef: {
              apiGroup: "rbac.authorization.k8s.io",
              kind: "Role",
              name: role.metadata.name,
            },
            subjects: [
              {
                kind: "ServiceAccount",
                name: "default",
                namespace,//namespace jenkins is deployed in
              },
            ],
          },
          {
            dependsOn: [role],
            provider: clusterK8sProvider
          }
        );

      })

    }

  });

}

execute();
