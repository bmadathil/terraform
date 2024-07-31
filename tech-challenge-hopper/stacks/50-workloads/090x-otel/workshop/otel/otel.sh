helm repo add signoz https://charts.signoz.io
helm repo list
kubectl create ns platform
helm --namespace platform install my-release signoz/signoz -f otelValues.yaml

