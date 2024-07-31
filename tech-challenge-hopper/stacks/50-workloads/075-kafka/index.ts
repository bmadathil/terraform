import * as k8s from "@pulumi/kubernetes";

import { config } from "./config";
import { getClusterConfig } from "../cluster-config";
import { EnvFrom, ExternalSecret } from "../interfaces";
import { createExternalSecret, retrieveCredentials } from "./functions";

interface Workload {
  name: string;
  host: string;
  version: string;
  replicas: number;
  adminCredentials: ExternalSecret;
  connect: {
    imageTag: string;
    envFrom: EnvFrom[];
  }
}

const UI = "kafka-ui";
const KAFKA = "kafka-broker";
const KSQLDB = "ksqldb-server";
const CONNECT = "connect";
const ZOOKEEPER = "zookeeper";
const SCHEMA_REGISTRY = "schema-registry";

const clusterK8sProvider = new k8s.Provider(
  "k8s-provider",
  { kubeconfig: config.kubeconfig }
);

async function execute() {
  
  const clusterConfig = await getClusterConfig();
 
  clusterConfig.namespaces.forEach(async (ns) => {

    const namespace = ns.name;

    const workload: Workload = ns.workloads.find(
      (wl: Workload) => wl.name === "kafka"
    );

    if (workload) {

      let key = `${namespace}-${ZOOKEEPER}`;
      new k8s.apps.v1.Deployment(
        `${key}-release`,
        {
          metadata: {
            name: ZOOKEEPER,
            namespace,
          },
          spec: {
            replicas: workload.replicas,
            selector: {
              matchLabels: { app: ZOOKEEPER }
            },
            strategy: { type: "Recreate" },
            template: {
              metadata: {
                labels: { app: ZOOKEEPER }
              },
              spec: {
                containers: [
                  {
                    name: ZOOKEEPER,
                    image: `confluentinc/cp-zookeeper:${workload.version}`,
                    ports: [
                      { containerPort: 2181 }
                    ],
                    env: [
                      { name: "ZOOKEEPER_CLIENT_PORT", value: "2181" },
                      { name: "ZOOKEEPER_TICK_TIME", value: "2000" },
                    ]
                  }
                ]
              }
            }
          }
        },
        { provider: clusterK8sProvider }
      );
      
      new k8s.core.v1.Service(
        `${key}-service`,
        {
          metadata: {
            name: ZOOKEEPER,
            namespace,
          },
          spec: {
            ports: [
              {
                name: "client",
                port: 2181,
                targetPort: 2181,
              }
            ],
            selector: { app: ZOOKEEPER },
          },
        },
        { provider: clusterK8sProvider }
      );

      key = `${namespace}-${KAFKA}`;
      new k8s.apps.v1.Deployment(
        `${key}-release`,
        {
          metadata: {
            name: KAFKA,
            namespace,
          },
          spec: {
            replicas: workload.replicas,
            selector: {
              matchLabels: { app: KAFKA }
            },
            strategy: { type: "Recreate" },
            template: {
              metadata: {
                labels: { app: KAFKA }
              },
              spec: {
                containers: [
                  {
                    name: KAFKA,
                    image: `confluentinc/cp-server:${workload.version}`,
                    ports: [
                      { containerPort: 9092 },
                      { containerPort: 9101 }
                    ],
                    env: [
                      { name: "KAFKA_BROKER_ID", value: "1" },
                      { name: "KAFKA_ZOOKEEPER_CONNECT", value: `${ZOOKEEPER}:2181` },
                      { name: "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP", value: "PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT" },
                      { name: "KAFKA_ADVERTISED_LISTENERS", value: `PLAINTEXT://${KAFKA}:9092,PLAINTEXT_HOST://localhost:9091` },
                      { name: "KAFKA_METRIC_REPORTERS", value: "io.confluent.metrics.reporter.ConfluentMetricsReporter" },
                      { name: "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR", value: "1" },
                      { name: "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS", value: "0" },
                      { name: "KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR", value: "1" },
                      { name: "KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR", value: "1" },
                      { name: "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR", value: "1" },
                      { name: "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR", value: "1" },
                      { name: "KAFKA_JMX_PORT", value: "9101" },
                      { name: "KAFKA_JMX_HOSTNAME", value: "localhost" },
                      { name: "KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL", value: `http://${SCHEMA_REGISTRY}:8081` },
                      { name: "CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS", value: `${KAFKA}:9092` },
                      { name: "CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS", value: "1" },
                      { name: "CONFLUENT_METRICS_ENABLE", value: "true" },
                      { name: "CONFLUENT_SUPPORT_CUSTOMER_ID", value: "anonymous" }
                    ],
                  }
                ],
                affinity: {
                  podAntiAffinity: {
                    requiredDuringSchedulingIgnoredDuringExecution: [
                      {
                        labelSelector: {
                          matchLabels: { app: KAFKA },
                        },
                        topologyKey: "kubernetes.io/hostname",
                      }
                    ],
                  },
                },
              },
            },
          },
        },
        { provider: clusterK8sProvider }
      );

      new k8s.core.v1.Service(
        `${key}-service`,
        {
          metadata: {
            name: KAFKA,
            namespace,
          },
          spec: {
            ports: [
              { name: "broker", port: 9092, targetPort: 9092 },
              { name: "metrics", port: 9101, targetPort: 9101 },
            ],
            selector: { app: KAFKA },
          },
        },
        { provider: clusterK8sProvider }
      );

      key = `${namespace}-${CONNECT}`;
      const connectRelease = new k8s.apps.v1.Deployment(
        `${key}-release`,
        {
          metadata: {
            name: CONNECT,
            namespace,
          },
          spec: {
            replicas: workload.replicas,
            selector: {
              matchLabels: { app: CONNECT }
            },
            strategy: { type: "Recreate" },
            template: {
              metadata: {
                labels: { app: CONNECT }
              },
              spec: {
                imagePullSecrets: [
                  { name: "ghcr-pull-secret" }
                ],
                containers: [
                  {
                    name: CONNECT,
                    image: workload.connect.imageTag,
                    ports: [
                      { containerPort: 8083 }
                    ],
                    env: [
                      { name: "CONNECT_BOOTSTRAP_SERVERS", value: `${KAFKA}:9092` },
                      { name: "CONNECT_REST_ADVERTISED_HOST_NAME", value: CONNECT },
                      { name: "CONNECT_GROUP_ID", value: "connect-group" },
                      { name: "CONNECT_CONFIG_STORAGE_TOPIC", value: "connect-configs" },
                      { name: "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR", value: "1" },
                      { name: "CONNECT_OFFSET_FLUSH_INTERVAL_MS", value: "10000" },
                      { name: "CONNECT_OFFSET_STORAGE_TOPIC", value: "connect-offsets" },
                      { name: "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR", value: "1" },
                      { name: "CONNECT_STATUS_STORAGE_TOPIC", value: "connect-status" },
                      { name: "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR", value: "1" },
                      { name: "CONNECT_KEY_CONVERTER", value: "org.apache.kafka.connect.storage.StringConverter" },
                      { name: "CONNECT_VALUE_CONVERTER", value: "org.apache.kafka.connect.json.JsonConverter" },
                      { name: "CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL", value: `http://${SCHEMA_REGISTRY}:8081` },
                      { name: "CONNECT_PLUGIN_PATH", value: "/usr/share/connectors,/usr/share/java,/usr/share/confluent-hub-components" },
                      { name: "CONNECT_LOG4J_LOGGERS", value: "org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR" },
                      ...workload.connect.envFrom,
                    ],
                  }
                ],
                affinity: {
                  podAntiAffinity: {
                    requiredDuringSchedulingIgnoredDuringExecution: [
                      {
                        labelSelector: {
                          matchLabels: { app: CONNECT },
                        },
                        topologyKey: "kubernetes.io/hostname",
                      }
                    ],
                  },
                },
              },
            },
          },
        },
        { provider: clusterK8sProvider }
      );
      
      const connectService = new k8s.core.v1.Service(
        `${key}-service`,
        {
          metadata: {
            name: CONNECT,
            namespace,
          },
          spec: {
            ports: [
              { name: "http", port: 8083, targetPort: 8083 },
             ],
            selector: { app: CONNECT },
          },
        },
        { provider: clusterK8sProvider }
      );

      key = `${namespace}-${SCHEMA_REGISTRY}`;
      new k8s.apps.v1.Deployment(
        `${key}-release`,
        {
          metadata: {
            name: SCHEMA_REGISTRY,
            namespace,
          },
          spec: {
            replicas: workload.replicas,
            selector: {
              matchLabels: { app: SCHEMA_REGISTRY }
            },
            strategy: { type: "Recreate" },
            template: {
              metadata: {
                labels: { app: SCHEMA_REGISTRY }
              },
              spec: {
                enableServiceLinks: false,
                containers: [
                  {
                    name: SCHEMA_REGISTRY,
                    image: `confluentinc/cp-schema-registry:${workload.version}`,
                    ports: [
                      { containerPort: 8081 }
                    ],
                    env: [
                      { name: "SCHEMA_REGISTRY_HOST_NAME", value: SCHEMA_REGISTRY },
                      { name: "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS", value: `${KAFKA}:9092` },
                      { name: "SCHEMA_REGISTRY_LISTENERS", value: "http://0.0.0.0:8081" },
                    ],
                  }
                ],
                affinity: {
                  podAntiAffinity: {
                    requiredDuringSchedulingIgnoredDuringExecution: [
                      {
                        labelSelector: {
                          matchLabels: { app: SCHEMA_REGISTRY },
                        },
                        topologyKey: "kubernetes.io/hostname",
                      },
                    ],
                  },
                },
              },
            },
          },
        },
        { provider: clusterK8sProvider }
      );
      
      new k8s.core.v1.Service(
        `${key}-service`,
        {
          metadata: {
            name: SCHEMA_REGISTRY,
            namespace,
          },
          spec: {
            ports: [
              { name: "http", port: 8081, targetPort: 8081 },
            ],
            selector: { app: SCHEMA_REGISTRY },
          },
        },
        { provider: clusterK8sProvider }
      );

      key = `${namespace}-${KSQLDB}`;
      new k8s.apps.v1.Deployment(
        `${key}-release`,
        {
          metadata: {
            name: KSQLDB,
            namespace,
          },
          spec: {
            replicas: workload.replicas,
            selector: {
              matchLabels: { app: KSQLDB }
            },
            strategy: { type: "Recreate" },
            template: {
              metadata: {
                labels: { app: KSQLDB }
              },
              spec: {
                containers: [
                  {
                    name: KSQLDB,
                    image: `confluentinc/cp-ksqldb-server:${workload.version}`,
                    ports: [
                      { containerPort: 8088 }
                    ],
                    env: [
                      { name: "KSQL_CONFIG_DIR", value: "/etc/ksql" },
                      { name: "KSQL_BOOTSTRAP_SERVERS", value: `${KAFKA}:9092` },
                      { name: "KSQL_HOST_NAME", value: KSQLDB },
                      { name: "KSQL_LISTENERS", value: "http://0.0.0.0:8088" },
                      { name: "KSQL_CACHE_MAX_BYTES_BUFFERING", value: "0" },
                      { name: "KSQL_KSQL_SCHEMA_REGISTRY_URL", value: `http://${SCHEMA_REGISTRY}:8081` },
                      { name: "KSQL_PRODUCER_INTERCEPTOR_CLASSES", value: "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor" },
                      { name: "KSQL_CONSUMER_INTERCEPTOR_CLASSES", value: "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor" },
                      { name: "KSQL_KSQL_CONNECT_URL", value: `http://${CONNECT}:8083` },
                      { name: "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_REPLICATION_FACTOR", value: "1" },
                      { name: "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_AUTO_CREATE", value: "true" },
                      { name: "KSQL_KSQL_LOGGING_PROCESSING_STREAM_AUTO_CREATE", value: "true" },
                    ],
                  }
                ],
                affinity: {
                  podAntiAffinity: {
                    requiredDuringSchedulingIgnoredDuringExecution: [
                      {
                        labelSelector: {
                          matchLabels: { app: KSQLDB },
                        },
                        topologyKey: "kubernetes.io/hostname",
                      }
                    ],
                  },
                },
              },
            },
          },
        },
        { provider: clusterK8sProvider }
      );

      new k8s.core.v1.Service(
        `${key}-service`,
        {
          metadata: {
            name: KSQLDB,
            namespace,
          },
          spec: {
            ports: [
              { name: "http", port: 8088, targetPort: 8088 },
             ],
            selector: { app: KSQLDB },
          },
        },
        { provider: clusterK8sProvider }
      );

      const adminSecret = await createExternalSecret(
        namespace, workload.adminCredentials, clusterK8sProvider
      );

      const adminCredentials = await retrieveCredentials(
        workload.adminCredentials, true,
      );

      key = `${namespace}-${UI}`;
      const uiConfigMap = new k8s.core.v1.ConfigMap(
        `${key}-configmap`,
        {
          metadata: {
            name: `${UI}-configmap`,
            namespace,
          },
          data: {
            "dynamic_config.yaml": `---
auth:
  type: LOGIN_FORM
spring:
  security:
    user:
      name: ${adminCredentials.username}
      password: ${adminCredentials.password}
kafka:
  clusters:
    - name: kafka
      bootstrapServers: ${KAFKA}:9092
      ksqlDbServer: http://${KSQLDB}:8088
      schemaRegistry: http://${SCHEMA_REGISTRY}:8081
      kafkaConnect:
        - name: ${CONNECT}
          address: http://${CONNECT}:8083`,
          },
        },
        { provider: clusterK8sProvider }
      );

      new k8s.helm.v3.Release(
        `${key}-release`,
        {
          name: UI,
          namespace,
          chart: "./kafka-ui",
          values: {
            replicaCount: workload.replicas,
            volumeMounts: [
              {
                name: uiConfigMap.metadata.name,
                mountPath: "/etc/kafkaui/dynamic_config.yaml",
                subPath: "dynamic_config.yaml",
              }
            ],
            volumes: [
              {
                name: uiConfigMap.metadata.name,
                configMap: { name: uiConfigMap.metadata.name },
              }
            ],
            env: [
              { name: "DYNAMIC_CONFIG_ENABLED", value:"true" }
            ],
          }
        },
        { provider: clusterK8sProvider }
      );

      new k8s.apiextensions.CustomResource(
        `${key}-ingressroute`,
        {
          apiVersion: "traefik.io/v1alpha1",
          kind: "IngressRoute",
          metadata: {
            name: `${UI}-ingress`,
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
                    name: UI,
                    kind: "Service",
                    namespace,
                    port: 80 
                  },
                ],
              },
            ],
            tls: { certResolver: "le" },
          },
        },
        { provider: clusterK8sProvider }
      );

    }

  });

}

execute();
