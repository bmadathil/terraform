import * as aws from "@pulumi/aws";
import * as k8s from "@pulumi/kubernetes";

import { Credentials, ExternalSecret } from "../interfaces";

const USERNAME = "username";
const PASSWORD = "password";

export async function createExternalSecret(
  namespace: string,
  secret: ExternalSecret,
  provider: k8s.Provider,
) {

  let labels = secret.labels || {};
  let annotations = secret.annotations || {};

  if (
    secret.allowedNamespaces &&
    secret.allowedNamespaces.length > 0
  ) {
    annotations = {
      ...annotations,
      "reflector.v1.k8s.emberstack.com/reflection-allowed": "true",
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled": "true",
      "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces":
        secret.allowedNamespaces.join(","),
    }
  }

  return new k8s.apiextensions.CustomResource(
    `${namespace}-${secret.name}-external-secrets`,
    {
      apiVersion: "external-secrets.io/v1beta1",
      kind: "ExternalSecret",
      metadata: {
        name: `${secret.name}-external-secrets`,
        namespace,
      },
      spec: {
        refreshInterval: secret.refreshInterval || "1h",
        secretStoreRef: {
          name: "external-secrets-store",
          kind: "SecretStore",
        },
        target: {
          name: secret.name,
          creationPolicy: "Owner",
          template: {
            type: secret.type || "opaque",
            metadata: {
              annotations,
              labels,
            },
          },
        },
        data: secret.data,
      },
    },
    { provider }
  );
}

export async function retrieveCredentials(
  credentials: ExternalSecret,
  getSecret?: boolean,
): Promise<Credentials> {
  let username = "admin";
  let password = "admin123";

  const usernameCredentials = credentials.data.find(
    item => item.secretKey.includes(USERNAME)
  );

  const passwordCredentials = credentials.data.find(
    item => item.secretKey.includes(PASSWORD)
  );

  if (getSecret) {
    const awsSecret = await aws.secretsmanager.getSecretVersion({
      secretId: usernameCredentials?.remoteRef.key || "",
    });
    
    const secretData = JSON.parse(awsSecret.secretString);

    username = secretData[
      usernameCredentials?.remoteRef.property || USERNAME
    ];

    password = secretData[
      passwordCredentials?.remoteRef.property || PASSWORD
    ];
  }

  return {
    userSecretKey: usernameCredentials?.secretKey || USERNAME,
    passwordSecretKey: passwordCredentials?.secretKey || PASSWORD,
    username,
    password,
  }
}
