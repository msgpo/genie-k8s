#!/bin/bash

. config
. lib.sh

parse_args "$0" "experiment dataset_owner dataset model task_name" "$@"
shift $n
check_config "IAM_ROLE OWNER DATASET_OWNER IMAGE train_task_name"

JOB_NAME=${OWNER}-evaluate-${experiment}-${model}
cmdline="--owner ${OWNER} --dataset_owner ${DATASET_OWNER} --task_name ${train_task_name} --experiment ${experiment} --dataset ${dataset} --model ${model} --workdir ${workdir} -- "$(requote "$@")

set -e
set -x
replace_config evaluate.yaml.in > evaluate.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f evaluate.yaml
