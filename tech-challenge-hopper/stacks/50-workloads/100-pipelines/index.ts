import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { ExternalSecret } from "../interfaces";
import { retrieveCredentials } from "./functions";
import { getClusterConfig } from "../cluster-config";

interface Workload {
  name: string;
  host: string;
  adminCredentials: ExternalSecret;
}

const JENKINS = "jenkins";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {

  const clusterConfig = await getClusterConfig();

  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;
    const jenkinsUrl = `http://${JENKINS}.${namespace}.svc.cluster.local:8080`;
    
    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === JENKINS
    );

    if (workload) {

      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials
      );

      new k8s.batch.v1.Job(
        "trigger-jenkins-seed-job",
        {
          metadata: {
            name: "trigger-jenkins-seed-job",
            namespace,
          },
          spec: {
            backoffLimit: 10,
            template: {
              spec: {
                containers: [
                  {
                    name: "trigger-jenkins-seed-job",
                    image: "curlimages/curl",
                    command: ["/bin/sh"],
                    args: [
                      "-c",
                      `CRUMB=$(curl --silent --user $USERNAME:$PASSWORD --cookie-jar /tmp/cookies '${jenkinsUrl}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)') \\
                        && echo "Got a crumb ($CRUMB)." \\
                        && TOKEN=$(curl --silent --user $USERNAME:$PASSWORD --header $CRUMB \\
                          --cookie /tmp/cookies '${jenkinsUrl}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken' \
                          --data 'newTokenName=AdminToken' | sed -E 's/.*"tokenValue":s*"([^"]+)".*/\\1/') \\
                        && echo "Made a token ($TOKEN)." \\
                        && curl --silent -X POST --user $USERNAME:$TOKEN --header $CRUMB ${jenkinsUrl}/job/seeder/build`,
                    ],
                    env: [
                      {
                        name: "USERNAME",
                        valueFrom: {
                          secretKeyRef: {
                            name: workload.adminCredentials.name,
                            key: adminCredentials.userSecretKey,
                          },
                        },
                      },
                      {
                        name: "PASSWORD",
                        valueFrom: {
                          secretKeyRef: {
                            name: workload.adminCredentials.name,
                            key: adminCredentials.passwordSecretKey,
                          },
                        },
                      },
                    ],
                  },
                ],
                restartPolicy: "Never",
              },
            },
          },
        },
        {
          provider: clusterK8sProvider,
          replaceOnChanges: ["*"],
          deleteBeforeReplace: true,
        }
      );

    }

  });

}

execute();
