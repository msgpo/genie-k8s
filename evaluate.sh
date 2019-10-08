#!/bin/bash

. config
. lib.sh

parse_args "$0" "experiment dataset model" "$@"
shift $n

JOB_NAME=${OWNER}-evaluate-${experiment}-${dataset}-${model}
cmdline="--owner ${owner} --experiment $experiment --dataset $dataset --model $model "$(requote "$@")

set -e
set -x
replace_config evaluate.yaml.in > evaluate.yaml

#kubectl -n research delete job ${JOB_NAME} || true
#kubectl apply -o yaml -f evaluate.yaml
