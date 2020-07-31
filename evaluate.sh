#!/bin/bash

. config
. lib.sh

parse_args "$0" "experiment model dataset model_owner=${OWNER} pred_languages=en pred_set_name=eval task_name=${TRAIN_TASK_NAME}" "$@"
shift $n
check_config "S3_BUCKET OWNER IMAGE PROJECT"

JOB_NAME=${OWNER}-evaluate-"${experiment//_/-}"-${model}-"${pred_set_name//_/-}"
cmdline="--s3_bucket ${S3_BUCKET} --owner ${OWNER} --project ${PROJECT} --experiment ${experiment} --task_name \"${task_name}\" --dataset ${dataset} --model ${model} --model_owner ${model_owner} --pred_languages ${pred_languages} --pred_set_name ${pred_set_name} -- "$(requote "$@")

set -e
set -x
replace_config evaluate.yaml.in > evaluate.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f evaluate.yaml
