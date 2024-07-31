#!/bin/bash
source ./func.sh

dir="90_post"

hdr "Applying post deployment actions"

## --- get kubeconfig

# msg "Get kubeconfig"
# aws ssm get-parameter --name /$CLUSTER_NAME/kubeconfig --with-decrypt --output text --query Parameter.Value >/hopper/runtime/kubeconfig
kubeconfig=$(cat /hopper/runtime/kubeconfig)

## --- sonarqube
# msg "TODO:SQ: generate new admin password and replace default"

# sq_new_admin_pw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
# sq_url=$(kubectl get svc sonarqube-sonarqube -n sonarqube -o json --kubeconfig /hopper/runtime/kubeconfig | jq -r '.status.loadBalancer.ingress[].hostname'):9000
# curl -G -X POST -v -u admin:admin \
#     --data-urlencode "login=admin" \
#     --data-urlencode "password=$sq_new_admin_pw" \
#     --data-urlencode "previousPassword=admin" \
#     "http://$sq_url/api/users/change_password" >/dev/null

# msg "TODO:SQ: create webhook for jenkins"

# curl -G -X POST -v -u admin:$sq_new_admin_pw  \
#     --data-urlencode "name=Jenkins" \
#     --data-urlencode "url=http://jenkins.$CLUSTER_DOMAIN:8080/sonarqube-webhook/" \
#     "http://$sq_url/api/webhooks/create"

# msg "TODO:SQ: create sonarqube admin token"

# sq_admin_token=$(curl -G -s -X POST -u admin:$sq_new_admin_pw --data-urlencode "name=jenkins-token" \
#     "http://$sq_url/api/user_tokens/generate" | jq .token)

# msg "TODO:SQ: create sonarqube non-admin user"

# sq_user_pw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
# curl -G -X POST -v -u admin:$sq_new_admin_pw \
#     --data-urlencode "login=hopper" \
#     --data-urlencode "name=hopper" \
#     --data-urlencode "password=$sq_user_pw" \
#     "http://$sq_url/api/users/create"

# msg "TODO:SQ: create k8s secret for token"

# cat <<EOF | kubectl apply --kubeconfig /hopper/runtime/kubeconfig -f -
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       labels:
#         jenkins.io/credentials-type: secretText
#       name: sonarqube-user-token
#       namespace: jenkins
#     type: Opaque
#     stringData:
#       text: $sq_admin_token
# EOF

## --- docker config (ghcr.io access)

# msg "TODO:DC: create docker config secrets"

# user Personal Access Token that has admin:repo_hook, repo, write:packages (one account for ease)
# dc_name_token=$(echo -n "username:token" | base64)
# dc_auth=$(echo -n '{"auths":{"ghcr.io":{"auth":"$dc_name_token"}}}' | base64)

# declare -a envArr=("dev" "e2e" "prod")

# for env in "${arr[@]}"; do
# cat <<EOF | kubectl apply --kubeconfig /hopper/runtime/kubeconfig -f -
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       name: dockerconfigjson-ghcr
#       namespace: $env
#     data:
#       .dockerconfigjson: $dc_auth
# EOF
# done

# use in pod/container:
# spec:
# containers:
# - name: name
# image: ghcr.io/username/imagename:label
# imagePullPolicy: Always
# imagePullSecrets:
# - name: dockerconfigjson-ghcr

## --- kubeconfig for Jenkins usage

# msg "TODO:J: kubeconfig secret"

# cat <<EOF | kubectl apply --kubeconfig /hopper/runtime/kubeconfig -f -
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       labels:
#         jenkins.io/credentials-type: secretText
#       name: kubeconfig
#       namespace: jenkins
#     type: Opaque
#     stringData:
#       text: '$kubeconfig'
# EOF

## --- username/token for GitHub user (repo access)

# msg "TODO:J: github secret"

# cat <<EOF | kubectl apply --kubeconfig /hopper/runtime/kubeconfig -f -
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       annotations:
#         jenkins.io/credentials-description: GitHub username/PAT with repo and registry access
#       labels:
#         jenkins.io/credentials-type: usernamePassword
#       name: github-creds  
#       namespace: jenkins
#     type: Opaque
#     data:
#       username: $(echo -n "$(aws ssm get-parameter --name /$CLUSTER_NAME/github-username --with-decrypt --output text --query Parameter.Value)" | base64 -w0) 
#       password: $(echo -n "$(aws ssm get-parameter --name /$CLUSTER_NAME/github-pat --with-decrypt --output text --query Parameter.Value)" | base64 -w0)
# EOF

## --- rds host and password

# msg "TODO:RDS: host/password secret"

# for env in "${arr[@]}"; do
# cat <<EOF | kubectl apply --kubeconfig /hopper/runtime/kubeconfig -f -
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       name: rds
#       namespace: $env
#     type: Opaque
#     stringData:
#       host: $(echo -n "$(aws ssm get-parameter --name /$CLUSTER_NAME/rds-host --with-decrypt --output text --query Parameter.Value)" | base64 -w0) 
#       password: $(echo -n "$(aws ssm get-parameter --name /$CLUSTER_NAME/rds-password --with-decrypt --output text --query Parameter.Value)" | base64 -w0)
# EOF
# done

## --- make cluster info available

# for env in "${arr[@]}"; do
# cat <<EOF | kubectl apply --kubeconfig /hopper/runtime/kubeconfig -f -
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       name: clusterInfo
#       namespace: $env
#     type: Opaque
#     stringData:
#       name: $(echo -n "$(aws ssm get-parameter --name /$CLUSTER_NAME/cluster-name --with-decrypt --output text --query Parameter.Value)" | base64 -w0) 
#       domain: $(echo -n "$(aws ssm get-parameter --name /$CLUSTER_NAME/cluster-domain --with-decrypt --output text --query Parameter.Value)" | base64 -w0)
# EOF
# done

## --- output connections and credentials

# msg "TDOD: connections and credentials; tie into new port-forward container"

# ui_url=$(kubectl get svc hopper-front-end -n hopper-dev -o json --kubeconfig /hopper/runtime/kubeconfig | jq -r '.status.loadBalancer.ingress[].hostname')
# # ui
# hdr "Web UI"
# msg "$ui_url"


# be_url=$(kubectl get svc hopper-back-end -n hopper-dev -o json --kubeconfig /hopper/runtime/kubeconfig | jq -r '.status.loadBalancer.ingress[].hostname')
# # swagger
# hdr "Swagger API"
# msg "$be_url"

# # jenkins
# j_url=$(kubectl get svc jenkins -n jenkins -o json --kubeconfig /hopper/runtime/kubeconfig | jq -r '.status.loadBalancer.ingress[].hostname')
# hdr "Jenkins"
# msg $j_url"
# msg "admin"
# msg "$j_admin_pw"

# sq_url=$(kubectl get svc sonarqube-sonarqube -n sonarqube -o json --kubeconfig /hopper/runtime/kubeconfig | jq -r '.status.loadBalancer.ingress[].hostname')
# hdr "Sonarqube"
# msg "$sq_url"
# msg "admin"
# msg "$sq_new_admin_pw"

# hdr "Jenkins"
# msg "user:" $(kubectl get secret/jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-user}' | base64 --decode)
# msg "pass:" $(kubectl get secret/jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode)
