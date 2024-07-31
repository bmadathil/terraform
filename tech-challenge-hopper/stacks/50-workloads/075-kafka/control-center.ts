// const adminUsername = "admin"
// const adminPassword = "admin123"
// key = `${namespace}-${CONTROL_CENTER}`;

// const ccConfigMap = new k8s.core.v1.ConfigMap(
//   `${key}-configmap`,
//   {
//     metadata: {
//       name: `${CONTROL_CENTER}-configmap`,
//       namespace,
//     },
//     data: {
//       "password.properties": `${adminUsername}: ${adminPassword},Administrators`,
//       "propertyfile.jaas": `c3 {
// org.eclipse.jetty.jaas.spi.PropertyFileLoginModule required
// file="/usr/shared/control-center/password.properties";
// };`,
//       "control-center.properties": `bootstrap.servers=${KAFKA}:9092
// confluent.controlcenter.data.dir=/var/lib/confluent-control-center
// confluent.monitoring.interceptor.topic.replication=1
// confluent.controlcenter.internal.topics.replication=1
// confluent.controlcenter.command.topic.replication=1
// confluent.metrics.topic.replication=1
// confluent.monitoring.interceptor.topic.partitions=1
// confluent.controlcenter.internal.topics.partitions=1
// confluent.controlcenter.ksql.ksqldb1.url=http://${KSQLDB}:8088
// confluent.controlcenter.ops=-Djava.security.auth.login.config=/usr/shared/control-center/propertyfile.jaas
// confluent.controlcenter.schema.registry.url=http://${SCHEMA_REGISTRY}:8081
// confluent.controlcenter.ksql.ksqldb1.advertised.url=http://localhost:8088
// confluent.controlcenter.connect.connect-default.cluster=connect:8083
// confluent.controlcenter.service.port=9021
// confluent.controlcenter.port.9021.tcp.proto=tcp
// confluent.controlcenter.config.dir=/etc/confluent-control-center
// confluent.controlcenter.port.9021.tcp.port=9021
// confluent.controlcenter.service.port.http=9021
// confluent.controlcenter.rest.authentication.method=BASIC
// confluent.controlcenter.rest.authentication.realm=c3
// confluent.controlcenter.rest.authentication.roles=Administrators,Restricted
// confluent.controlcenter.auth.restricted.roles=Restricted
// confluent.controlcenter.auth.session.expiration.ms=600000`,
//     },
//   },
//   { provider: clusterK8sProvider }
// );

// const controlCenterRelease = new k8s.apps.v1.Deployment(
//   `${key}-release`,
//   {
//     metadata: {
//       name: CONTROL_CENTER,
//       namespace,
//     },
//     spec: {
//       selector: {
//         matchLabels: { app: CONTROL_CENTER }
//       },
//       strategy: { type: "Recreate" },
//       template: {
//         metadata: {
//           labels: { app: CONTROL_CENTER }
//         },
//         spec: {
//           volumes: [
//             {
//               name: ccConfigMap.metadata.name,
//               configMap: { name: ccConfigMap.metadata.name },
//             }
//           ],
//           containers: [
//             {
//               name: CONTROL_CENTER,
//               image: workload.controlCenter.imageTag,
//               ports: [
//                 { containerPort: 9021 }
//               ],
//               volumeMounts: [
//                 {
//                   name: ccConfigMap.metadata.name,
//                   mountPath: "/usr/shared/control-center",
//                 }
//               ],
//               env: [
//                 //{ name: "PORT", value: "9021" },
//                 //{ name: "CONTROL_CENTER_OPS", value: "-Djava.security.auth.login.config=/usr/share/control-center/propertyfile.jaas" },
//                 //{ name: "CONTROL_CENTER_BOOTSTRAP_SERVERS", value: `${KAFKA}:9092` },
//                 //{ name: "CONTROL_CENTER_CONNECT_CONNECT-DEFAULT_CLUSTER", value: `${CONNECT}:8083` },
//                 //{ name: "CONTROL_CENTER_KSQL_KSQLDB1_URL", value: `http://${KSQLDB}:8088` },
//                 //{ name: "CONTROL_CENTER_KSQL_KSQLDB1_ADVERTISED_URL", value: "http://localhost:8088" },
//                 //{ name: "CONTROL_CENTER_SCHEMA_REGISTRY_URL", value: `http://${SCHEMA_REGISTRY}:8081` },
//                 //{ name: "CONTROL_CENTER_REPLICATION_FACTOR", value: "1" },
//                 //{ name: "CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS", value: "1" },
//                 //{ name: "CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS", value: "1" },
//                 //{ name: "CONFLUENT_METRICS_TOPIC_REPLICATION", value: "1" },
//                 //{ name: "CONFLUENT_CONTROLCENTER_REST_AUTHENTICATION_METHOD", value: "BASIC" },
//                 //{ name: "CONFLUENT_CONTROLCENTER_REST_AUTHENTICATION_REALM", value: "c3" },
//                 //{ name: "CONFLUENT_CONTROLCENTER_REST_AUTHENTICATION_ROLES", value: "Administrators,Restricted" },
//                 //{ name: "CONFLUENT_CONTROLCENTER_AUTH_RESTRICTED_ROLES", value: "Restricted" },
//                 //{ name: "CONFLUENT_CONTROLCENTER_AUTH_SESSION_EXPIRATION_MS", value: "600000" },
//               ],
//               command: ["control-center-start"],
//               args: ["/usr/shared/control-center/control-center.properties"],
//             },
//           ],
//           affinity: {
//             podAntiAffinity: {
//               requiredDuringSchedulingIgnoredDuringExecution: [
//                 {
//                   labelSelector: {
//                     matchLabels: { app: CONTROL_CENTER },
//                   },
//                   topologyKey: "kubernetes.io/hostname",
//                 },
//               ],
//             },
//           },
//         },
//       },
//     },
//   },
//   {
//     //dependsOn: [schemaRegistryRelease, kafkaRelease, connectRelease, ksqldbRelease],
//     provider: clusterK8sProvider,
//   }
// );

// const controlCenterService = new k8s.core.v1.Service(
//   `${key}-service`,
//   {
//     metadata: {
//       name: CONTROL_CENTER,
//       namespace,
//     },
//     spec: {
//       ports: [
//         { name: "http", port: 9021, targetPort: 9021 },
//        ],
//       selector: { app: CONTROL_CENTER },
//     },
//   },
//   {
//     //dependsOn: [controlCenterRelease],
//     provider: clusterK8sProvider,
//   }
// );

// new k8s.apiextensions.CustomResource(
//   `${key}-ingressroute`,
//   {
//     apiVersion: "traefik.io/v1alpha1",
//     kind: "IngressRoute",
//     metadata: {
//       name: `${CONTROL_CENTER}-ingressroute`,
//       namespace,
//     },
//     spec: {
//       entryPoints: ["websecure"],
//       routes: [
//         {
//           kind: "Rule",
//           match: `Host(\`${workload.host}\`)`,
//           services: [
//             {
//               name: CONTROL_CENTER,
//               kind: "Service",
//               namespace,
//               port: 9021 
//             },
//           ],
//         },
//       ],
//       tls: { certResolver: "le" },
//     },
//   },
//   {
//     //dependsOn: [controlCenterService],
//     provider: clusterK8sProvider,
//   }
// );
