#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: $0 {create|destroy|plan|help}"
    echo
    echo "Attention :    Update ./env file before creating or destroying modules"
    echo "          :    you can 'disable' and 'enable' modules by commenting and un-commenting using '#' in ./modules.txt file "
    echo "Commands  :"
    echo "  create    Run 'terraform apply' to create resources for each module"
    echo "  destroy   Run 'terraform destroy' to destroy resources for each module in reverse order"
    echo "  plan      Run 'terraform plan' to display plan of resources creating in each module"
    echo "  help      Display this help message"
}

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
    echo "Note !!!!!: Exactly one argument is required"
    show_help
    exit 1
fi

source ./env

# Parse the command
COMMAND=$1

MODULES=()
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    MODULES+=("$line")
done < modules.txt

# Function to create modules
plan_modules() {
    for MODULE in "${MODULES[@]}"; do
        echo "Running 'terraform execution plan' for module: $MODULE"
	( terraform plan -target=module.${MODULE} )
    done
}
create_modules() {
    for MODULE in "${MODULES[@]}"; do
        echo "Running 'terraform apply' for module: $MODULE"
        ( terraform apply -target=module.${MODULE} -auto-approve)
    done
}

# Function to destroy modules in reverse order
destroy_modules() {
    for (( idx=${#MODULES[@]}-1 ; idx>=0 ; idx-- )) ; do
        MODULE=${MODULES[idx]}
        echo "Running 'terraform destroy' for module: $MODULE"
        ( terraform destroy -target=module.${MODULE} -refresh=false -auto-approve)
    done
}

# Perform the requested operation
for MODULE in "${MODULES[@]}"; do
  case "$COMMAND" in
    create)
        create_modules
	break
        ;;
    destroy)
        destroy_modules
	break
        ;;
    plan)
        plan_modules
	break
        ;;
    help)
        show_help
        ;;
    *)
        echo "Error: Invalid command"
        show_help
        exit 1
        ;;
  esac
done  

