#!/bin/bash

. config
. lib.sh


set -x
set -e


parse_args "$0" "project experiment dataset model" "$@"
shift $n
check_config "IAM_ROLE OWNER DATASET_OWNER IMAGE PROJECT"


JOB_NAME=${OWNER}-paraphrase-${model}
cmdline="--owner ${OWNER} --dataset_owner ${DATASET_OWNER} --project $project --experiment $experiment --dataset $dataset --model $model -- "$(requote "$@")

set -e
set -x
replace_config train-paraphrase.yaml.in > train-paraphrase.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f train-paraphrase.yaml