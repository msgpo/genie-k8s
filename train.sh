#!/bin/bash

. config
. lib.sh

check_config "S3_BUCKET OWNER DATASET_OWNER IMAGE PROJECT"
parse_args "$0" "experiment dataset dataset_owner=${DATASET_OWNER} model task_name=${TRAIN_TASK_NAME} load_from=None num_gpus=1 train_languages=en eval_languages=en dlg_side=user" "$@"

shift $n

GPU_NUM=$num_gpus
GPU_TYPE="p3.$((2*$num_gpus))xlarge"

JOB_NAME=${OWNER}-train-${experiment}-${model}
cmdline="--s3_bucket ${S3_BUCKET} --owner ${OWNER} --dataset_owner ${dataset_owner} --task_name \"${task_name}\" --project ${PROJECT} --experiment $experiment --dataset $dataset --train_languages $train_languages --eval_languages $eval_languages --dlg_side $dlg_side --model $model --load_from \"${load_from}\" -- "$(requote "$@")

set -e
set -x
replace_config train.yaml.in > train.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f train.yaml
