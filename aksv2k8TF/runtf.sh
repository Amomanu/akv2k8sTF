read -p "Enter keyvault name: " env_key_vault_name

sed -i "s/kvnames/$env_key_vault_name/" "akvs-secret-sync.yaml"
sed -i "s/kvnames/$env_key_vault_name/" "akvs-secret-inject.yaml"

az login --tenant 9917dcc8-bdaf-4e03-928b-1e67b0d806c5 
az account set --subscription=a2d2880c-29d4-407f-bd42-08d4832d925e

terraform init
terraform apply --var key_vault_name="${env_key_vault_name}"

