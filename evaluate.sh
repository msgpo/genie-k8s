#!/bin/bash

. config
. lib.sh

set -x
set -e

check_config "IAM_ROLE OWNER DATASET_OWNER IMAGE PROJECT EVAL_TASK_NAME"

parse_args "$0" "experiment dataset model" "$@"
shift $n
psn="${@: -1}"


JOB_NAME=${OWNER}-evaluate-${experiment}-${model}-"${psn//_/-}"
cmdline="--owner ${OWNER} --dataset_owner ${DATASET_OWNER} --project ${PROJECT} --task_name ${EVAL_TASK_NAME} --experiment ${experiment} --dataset ${dataset} --model ${model} -- "$(requote "$@")

set -e
set -x
replace_config evaluate.yaml.in > evaluate.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f evaluate.yaml
