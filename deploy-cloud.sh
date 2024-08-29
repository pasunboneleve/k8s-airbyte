#!/bin/env bash

IFS=$'\n\t'
set -euox pipefail

environment=${1:-"dev"}
project_name="***REMOVED***-${environment}"
region=australia-southeast1
zone=${region}-b
instance_name=ingestion

gcloud compute instances delete ${instance_name} \
       --zone=${zone} \
       --project=${project_name} \
       --quiet || true

gcloud compute instances create ${instance_name} \
       --project=${project_name} \
       --zone=${zone} \
       --machine-type=custom-4-7680 \
       --no-address \
       --subnet=projects/***REMOVED***-vpc/regions/${region}/subnetworks/dpw-${environment} \
       --network-tier=STANDARD \
       --tags=allow-metrics,allow-ssh,egress-inet,loki-client \
       --scopes=https://www.googleapis.com/auth/cloud-platform \
       --service-account=ingestion@${project_name}.iam.gserviceaccount.com \
       --image-family ingestion \
       --boot-disk-size=30GB \
       --boot-disk-type=pd-standard \
       --boot-disk-device-name=${instance_name} \
       --metadata-from-file user-data=user-data \
       --maintenance-policy=MIGRATE \
       --provisioning-model=STANDARD
