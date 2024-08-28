#!/bin/env bash

IFS=$'\n\t'
set -uox pipefail

environment=${1:-"dev"}
project_name="***REMOVED***-${environment}"
region=australia-southeast1
zone=${region}-b

function getSecret {
  (
    gcloud secrets versions access latest \
    --secret="$1" --project=${project_name}
  )
}
set +x  # Don't log the password
database_password=$(getSecret ingestion_db_password)
set -x  # And now, back to our regularly scheduled programming.
db_instance_name=$(getSecret db_instance)

# set context (must be preexisting)
# kubectl create namespace ingestion
kubectl config set-context --current --namespace ingestion

# set secrets
kubectl create secret generic service-account --from-file=json=./service-account.json
kubectl create secret generic airbyte-config \
        --from-literal=database-user=airbyte \
        --from-literal=database-password=${database_password}
kubectl apply -f airbyte-secret.yaml -n ingestion

# instal cloudsql-proxy
helm upgrade --install pg-sqlproxy rimusz/gcloud-sqlproxy --namespace ingestion \
     --set existingSecret="service-account" \
     --set existingSecretKey=json \
     --set cloudsql.instances[0].instance=${db_instance_name} \
     --set cloudsql.instances[0].project=${project_name} \
     --set cloudsql.instances[0].region=${region} \
     --set cloudsql.instances[0].port=5432 -i \
     --set httpReadinessProbe.enabled=true \
     --set httpLivenessProbe.enabled=true \
     --set httpStartupProbe.enabled=true \
     --set livenessProbe.enabled=true \
     --set readinessProbe.enabled=true

# install the airbyte package
helm upgrade -i --values airbyte-values.yaml airbyte airbyte/airbyte

# port forward the frontend
#
# for development
# kubectl port-forward service/airbyte-airbyte-webapp-svc 8000:80
#
# create a service
kubectl expose deployment airbyte-webapp --type=NodePort
# get the IP and PORT of the service
minikube service airbyte-webapp --url -n ingestion
