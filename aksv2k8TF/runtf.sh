read -p "Enter keyvault name: " env_key_vault_name

sed -i "s/kvnames/$env_key_vault_name/" "akvs-secret-sync.yaml"
sed -i "s/kvnames/$env_key_vault_name/" "akvs-secret-inject.yaml"

az login --tenant 3ce02252-982a-4d82-ada3-a7a8d9617394
az account set --subscription=f297f3ca-3530-4fe1-b9b5-fda6f21aec1d

terraform init
terraform apply --var key_vault_name="${env_key_vault_name}"

