#!/bin/bash

. config
. lib.sh

check_config "IAM_ROLE OWNER DATASET_OWNER IMAGE PROJECT EVAL_TASK_NAME"

parse_args "$0" "experiment dataset model pred_languages=en pred_set_name=eval" "$@"
shift $n


JOB_NAME=${OWNER}-evaluate-${experiment}-${model}-"${pred_set_name//_/-}"
cmdline="--owner ${OWNER} --dataset_owner ${DATASET_OWNER} --project ${PROJECT} --task_name ${EVAL_TASK_NAME} --experiment ${experiment} --dataset ${dataset} --model ${model} --pred_languages ${pred_languages} --pred_set_name ${pred_set_name} -- "$(requote "$@")

set -e
set -x
replace_config evaluate.yaml.in > evaluate.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f evaluate.yaml
