#!/bin/sh

#!/bin/bash
echo "Argo-CD login    -  admin"
echo "Argo-CD password -  $(terraform output -raw argocd_initial_password)"
echo "Argo-CD URL      -  $(terraform output -raw argocd_url)"

echo "------------------------------------"

echo "PGadmin login    -  $(terraform output -raw pgadmin_initial_login )"
echo "PGadmin password -  $(terraform output -raw pgadmin_initial_password)"
echo "PGadmin URL      -  $(terraform output -raw pgadmin_url)"

echo "------------------------------------"

output_keycloak_info() {
    env=$1
    echo "Keycloak $env login    -  $(terraform output -raw keycloak_${env}_username)"
    echo "Keycloak $env password -  $(terraform output -raw keycloak_${env}_password)"
    echo "Keycloak $env URL      -  $(terraform output -raw keycloak_${env}_url)"
    echo "------------------------------------"
}

# Output for dev environment
output_keycloak_info "dev"

# Output for test environment
output_keycloak_info "test"

# Output for prod environment
output_keycloak_info "prod"

