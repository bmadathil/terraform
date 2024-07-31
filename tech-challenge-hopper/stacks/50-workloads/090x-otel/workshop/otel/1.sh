helm repo add signoz https://charts.signoz.io
helm repo list
kubectl create ns platform
helm --namespace platform install my-release signoz/signoz -f otelValues.yaml
helm install my-release1 signoz/k8s-infra  \
--set otelCollectorEndpoint=my-release-k8s-infra-otel-agent:4317

sample application

curl -sL https://github.com/SigNoz/signoz/raw/develop/sample-apps/hotrod/hotrod-install.sh   | HELM_RELEASE=signoz     SIGNOZ_NAMESPACE=otel     bash

kubectl --namespace sample-application run strzal --image=djbingham/curl \
  --restart='OnFailure' -i --tty --rm --command -- curl -X POST -F \
  'user_count=6' -F 'spawn_rate=2' http://locust-master:8089/swarm

to stop generating the load

kubectl -n sample-application run strzal --image=djbingham/curl \
  --restart='OnFailure' -i --tty --rm --command -- curl \
  http://locust-master:8089/stop
