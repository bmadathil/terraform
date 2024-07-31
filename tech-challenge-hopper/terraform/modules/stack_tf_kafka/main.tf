
provider "kubernetes" {
  config_path = var.kubeconfig
} 

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
  
provider "aws" { 
  region = var.region
}   

data "aws_caller_identity" "current" {}

resource "kubernetes_deployment" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "zookeeper"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "zookeeper"
        }
      }

      spec {
        container {
          name  = "zookeeper"
          image = "confluentinc/cp-zookeeper:7.6.1"

          port {
            container_port = 2181
          }

          env {
            name  = "ZOOKEEPER_CLIENT_PORT"
            value = "2181"
          }

          env {
            name  = "ZOOKEEPER_TICK_TIME"
            value = "2000"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "zookeeper"
    }

    port {
      name        = "client"
      port        = 2181
      target_port = 2181
    }
  }
}



resource "kubernetes_deployment" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        enable_service_links = false
        container {
          name  = "kafka"
          image = "confluentinc/cp-server:7.6.1"
          port {
            container_port = 9092
          }

          port {
            container_port = 9101
          }

          env {
            name  = "KAFKA_BROKER_ID"
            value = "1"
          }
          env {
            name  = "KAFKA_ZOOKEEPER_CONNECT"
            value = "zookeeper:2181"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT"
          }
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9091"
          }
          env {
            name  = "KAFKA_METRIC_REPORTERS"
            value = "io.confluent.metrics.reporter.ConfluentMetricsReporter"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS"
            value = "0"
          }
          env {
            name  = "KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_JMX_PORT"
            value = "9101"
          }
          env {
            name  = "KAFKA_JMX_HOSTNAME"
            value = "localhost"
          }
          env {
            name  = "KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL"
            value = "http://schema-registry:8081"
          }
          env {
            name  = "CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS"
            value = "kafka:9092"
          }
          env {
            name  = "CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS"
            value = "1"
          }
          env {
            name  = "CONFLUENT_METRICS_ENABLE"
            value = "true"
          }
          env {
            name  = "CONFLUENT_SUPPORT_CUSTOMER_ID"
            value = "anonymous"
          }
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "kafka"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "kafka"
    }

    port {
      name        = "broker"
      port        = 9092
      target_port = 9092
    }

    port {
      name        = "metrics"
      port        = 9101
      target_port = 9101
    }
  }
}


resource "kubernetes_deployment" "schema_registry" {
  metadata {
    name      = "schema-registry"
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "schema-registry"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "schema-registry"
        }
      }

      spec {
        enable_service_links = false

        container {
          name  = "schema-registry"
          image = "confluentinc/cp-schema-registry:7.3.0"

          port {
            container_port = 8081
          }

          env {
            name  = "SCHEMA_REGISTRY_HOST_NAME"
            value = "schema-registry"
          }

          env {
            name  = "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
            value = "kafka:9092"
          }

          env {
            name  = "SCHEMA_REGISTRY_LISTENERS"
            value = "http://0.0.0.0:8081"
          }
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "schema-registry"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "schema_registry" {
  metadata {
    name      = "schema-registry"
    namespace = var.namespace
  }

  spec {
    port {
      name        = "http"
      port        = 8081
      target_port = 8081
    }

    selector = {
      app = "schema-registry"
    }
  }
}


resource "kubernetes_deployment" "connect" {
  metadata {
    name      = "connect"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "connect"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "connect"
        }
      }

      spec {
        image_pull_secrets {
          name = "ghcr-pull-secret"
        }

        container {
          name  = "connect"
          image = "ghcr.io/cvpcorp/kafka-connect:1.0.3"
          port {
            container_port = 8083
          }

          env {
            name  = "CONNECT_BOOTSTRAP_SERVERS"
            value = "kafka:9092"
          }
          env {
            name  = "CONNECT_REST_ADVERTISED_HOST_NAME"
            value = "connect"
          }
          env {
            name  = "CONNECT_GROUP_ID"
            value = "connect-group"
          }
          env {
            name  = "CONNECT_CONFIG_STORAGE_TOPIC"
            value = "connect-configs"
          }
          env {
            name  = "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "CONNECT_OFFSET_FLUSH_INTERVAL_MS"
            value = "10000"
          }
          env {
            name  = "CONNECT_OFFSET_STORAGE_TOPIC"
            value = "connect-offsets"
          }
          env {
            name  = "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "CONNECT_STATUS_STORAGE_TOPIC"
            value = "connect-status"
          }
          env {
            name  = "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "CONNECT_KEY_CONVERTER"
            value = "org.apache.kafka.connect.storage.StringConverter"
          }
          env {
            name  = "CONNECT_VALUE_CONVERTER"
            value = "org.apache.kafka.connect.json.JsonConverter"
          }
          env {
            name  = "CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL"
            value = "http://schema-registry:8081"
          }
          env {
            name  = "CONNECT_PLUGIN_PATH"
            value = "/usr/share/connectors,/usr/share/java,/usr/share/confluent-hub-components"
          }
          env {
            name  = "CONNECT_LOG4J_LOGGERS"
            value = "org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR"
          }

          # Additional env variables from workload.connect.envFrom
           env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = "awssm-secret"
                key  = "access-key"
              }
            }
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "awssm-secret"
                key  = "secret-access-key"
              }
            }
          }
/*
          env {
            name = "APP_DB_USER"
            value_from {
              secret_key_ref {
                name = "app-db-credentials"
                key  = "username"
              }
            }
          }
          env {
            name = "APP_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "app-db-credentials"
                key  = "password"
              }
            }
          }
*/
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "connect"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "connect" {
  metadata {
    name      = "connect"
    namespace = var.namespace
  }

  spec {
    port {
      name        = "http"
      port        = 8083
      target_port = 8083
    }

    selector = {
      app = "connect"
    }
  }
}

resource "kubernetes_deployment" "ksqldb_server" {
  metadata {
    name      = "ksqldb-server"
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "ksqldb-server"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "ksqldb-server"
        }
      }

      spec {
        container {
          name  = "ksqldb-server"
          image = "confluentinc/cp-ksqldb-server:7.3.0"

          port {
            container_port = 8088
          }

          env {
            name  = "KSQL_CONFIG_DIR"
            value = "/etc/ksql"
          }
          env {
            name  = "KSQL_BOOTSTRAP_SERVERS"
            value = "kafka:9092"
          }
          env {
            name  = "KSQL_HOST_NAME"
            value = "ksqldb-server"
          }
          env {
            name  = "KSQL_LISTENERS"
            value = "http://0.0.0.0:8088"
          }
          env {
            name  = "KSQL_CACHE_MAX_BYTES_BUFFERING"
            value = "0"
          }
          env {
            name  = "KSQL_KSQL_SCHEMA_REGISTRY_URL"
            value = "http://schema-registry:8081"
          }
          env {
            name  = "KSQL_PRODUCER_INTERCEPTOR_CLASSES"
            value = "io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor"
          }
          env {
            name  = "KSQL_CONSUMER_INTERCEPTOR_CLASSES"
            value = "io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor"
          }
          env {
            name  = "KSQL_KSQL_CONNECT_URL"
            value = "http://connect:8083"
          }
          env {
            name  = "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_AUTO_CREATE"
            value = "true"
          }
          env {
            name  = "KSQL_KSQL_LOGGING_PROCESSING_STREAM_AUTO_CREATE"
            value = "true"
          }
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "ksqldb-server"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ksqldb_server" {
  metadata {
    name      = "ksqldb-server"
    namespace = var.namespace
  }

  spec {
    port {
      name        = "http"
      port        = 8088
      target_port = 8088
    }

    selector = {
      app = "ksqldb-server"
    }
  }
}

resource "kubernetes_deployment" "control_center" {
  metadata {
    name      = "control-center"
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = {
        app = "control-center"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "control-center"
        }
      }

      spec {
        container {
          name  = "control-center"
          image = "confluentinc/cp-enterprise-control-center:7.3.0"

          port {
            container_port = 9021
          }

          env {
            name  = "CONTROL_CENTER_BOOTSTRAP_SERVERS"
            value = "kafka:9092"
          }

          env {
            name  = "CONTROL_CENTER_CONNECT_CONNECT-DEFAULT_CLUSTER"
            value = "connect:8083"
          }

          env {
            name  = "CONTROL_CENTER_KSQL_KSQLDB1_URL"
            value = "http://ksqldb-server:8088"
          }

          env {
            name  = "CONTROL_CENTER_KSQL_KSQLDB1_ADVERTISED_URL"
            value = "http://localhost:8088"
          }

          env {
            name  = "CONTROL_CENTER_SCHEMA_REGISTRY_URL"
            value = "http://schema-registry:8081"
          }

          env {
            name  = "CONTROL_CENTER_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS"
            value = "1"
          }

          env {
            name  = "CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS"
            value = "1"
          }

          env {
            name  = "CONFLUENT_METRICS_TOPIC_REPLICATION"
            value = "1"
          }

          env {
            name  = "PORT"
            value = "9021"
          }
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "control-center"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "control_center" {
  metadata {
    name      = "control-center"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "control-center"
    }

    port {
      name        = "http"
      port        = 9021
      target_port = 9021
    }
  }
}

resource "kubernetes_manifest" "kafka_controlcenter_ingress" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "kafka-cc-ingress"
      namespace = var.namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`kafkacontrolcenter.${var.cluster_name}.${var.hosted_zone}`)"
          kind  = "Rule"
          services = [
            {
              name      = "control-center"
              kind      = "Service"
              namespace = var.namespace
              port      = 9021
            }
          ]
        }
      ]
      tls = {
        certResolver = "le"
      }
    }
  }
}

data "local_file" "ui_config" {
  filename = "${path.module}/kafka-ui/dynamic_config.yaml"
}

resource "kubernetes_config_map" "ui_config_map" {
  metadata {
    name      = "ui-config"
    namespace = var.namespace
  }

  data = {
    "dynamic_config.yaml"                    = data.local_file.ui_config.content
    AUTH_TYPE                                = "LOGIN_FORM"
    SPRING_SECURITY_USER_NAME                = "admin"
    SPRING_SECURITY_USER_PASSWORD            = "admin"
    DYNAMIC_CONFIG_ENABLED                   = "true"
    KAFKA_CLUSTERS_0_NAME                    = "kafka"
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS        = "kafka:9092"
    KAFKA_CLUSTERS_0_KSQLDBSERVER            = "http://ksqldb-server:8088"
    KAFKA_CLUSTERS_0_SCHEMAREGISTRY          = "http://schema-registry:8081"
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME     = "connect"
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS  = "http://connect:8083"
  }
}


resource "helm_release" "kafka_ui" {
  name       = "kafka-ui"
  namespace = var.namespace
  chart      = "${path.module}/kafka-ui"

  values = [
    yamlencode({
      volumeMounts = [
        {
          name      = "ui-volume"
          mountPath = "/etc/kafkaui/dynamic_config.yaml"
          subPath   = "dynamic_config.yaml"
        }
      ]
      volumes = [
        {
          name = "ui-volume"
          configMap = {
            name = "ui-config"
          }
        }
      ]
      env = [
        {
          name  = "DYNAMIC_CONFIG_ENABLED"
          value = "true"
        }
      ]
    })
  ]
}

resource "kubernetes_manifest" "kafkaui_ingress_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "kafkaui"
      namespace = var.namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`kafkaui.${var.cluster_name}.${var.hosted_zone}`)"
          kind  = "Rule"
          services = [
            {
              name      = "kafka-ui"
              kind      = "Service"
              namespace = var.namespace
              port      = 80
            }
          ]
        }
      ]
      tls = {
        certResolver = "le"
      }
    }
  }
}

