#!/bin/bash

. config
. lib.sh


parse_args "$0" "experiment=paraphrase dataset model wandb_key num_gpus=1 src_lang tgt_lang" "$@"
shift $n
check_config "S3_BUCKET OWNER DATASET_OWNER IMAGE PROJECT"

GPU_NUM=$num_gpus
GPU_TYPE="p3.$((2*$num_gpus))xlarge"

JOB_NAME=${OWNER}-transformers-${experiment}-`echo ${src_lang//_/-} | tr '[:upper:]' '[:lower:]'`-`echo ${tgt_lang//_/-} | tr '[:upper:]' '[:lower:]'`
cmdline="--s3_bucket ${S3_BUCKET} --owner ${OWNER} --dataset_owner ${DATASET_OWNER} --project ${PROJECT} \
  --experiment $experiment --dataset $dataset --model $model \
  --wandb_key $wandb_key --num_gpus $num_gpus --src_lang $src_lang --tgt_lang $tgt_lang  -- "$(requote "$@")

set -e
set -x
replace_config transformers.yaml.in > transformers.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f transformers.yaml
