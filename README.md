# akv2k8sTF
deploying akv2k8s with Terraform

It will create a KeyVault , a secret , a AKS cluster , assign permissions on the KeyVault for the cluster , create labeled namespace , install AKvsk8s via hel , install CRDs , install secret sync and secret inject .



How to run :
cd to path where main.tf exists
run runtf.sh
give name to keyvault




when deployment completed , test if secrets are properly synced : 
kubectl -n aks-namespace get akvs

check if the value of the env var is listed :

kubectl -n aks-namespace logs deployment/akvs-secret-app
