#!/bin/env bash

IFS=$'\n\t'
set -euox pipefail

environment=${1:-"dev"}
project_name="***REMOVED***-${environment}"
region=australia-southeast1
zone=${region}-b
db_instance_name="dpw-4d9362fefa"

# set context (must be preexisting)
# kubectl create namespace ingestion
kubectl config set-context --current --namespace ingestion

# set secrets
kubectl apply -f airbyte-secret.yaml -n ingestion

# instal cloudsql-proxy
helm upgrade --install pg-sqlproxy rimusz/gcloud-sqlproxy --namespace ingestion \
    --set serviceAccountKey="$(cat service-account.json | base64 | tr -d '\n')" \
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
kubectl port-forward service/airbyte-airbyte-webapp-svc 8000:80
