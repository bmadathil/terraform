export interface EnvFrom {
  name: string;
  valueFrom: {
    secretKeyRef: {
      name: string;
      key: string;
    }
  }
}

export interface Database {
  port: number;
  name: string;
  host: string;
  user: string;
  external: boolean;
  secret: {
    name: string;
    userKey: string;
    passwordKey: string;
  };
}

export interface Credentials {
  userSecretKey: string;
  passwordSecretKey: string;
  username: string;
  password: string;
}

export interface ExternalSecret {
  name: string,
  type: string,
  refreshInterval: string,
  allowedNamespaces: string[],
  annotations: {},
  labels: {},
  data: [
    {
      secretKey: string,
      remoteRef: {
        key: string,
        property: string
      }
    }
  ],
  dataFrom: [
    {
      extract: {
        key: string
      }
    }
  ]
}
