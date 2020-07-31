#!/bin/bash

. config
. lib.sh


parse_args "$0" " experiment input_splits model_name_or_path=None tgt_lang=None dlg_side=user process_english=false do_translation=false process_translations=false retranslate_erred_examples=false num_gpus=1" "$@"
shift $n
check_config "S3_BUCKET OWNER DATASET_OWNER IMAGE PROJECT TRAIN_TASK_NAME"

GPU_NUM=$num_gpus
GPU_TYPE="p3.$((2*$num_gpus))xlarge"

JOB_NAME=${OWNER}-translate-${experiment}-${tgt_lang}
cmdline="--s3_bucket ${S3_BUCKET} --owner ${OWNER} --dataset_owner ${DATASET_OWNER} --project ${PROJECT} --experiment $experiment \
         --input_splits $input_splits  --dlg_side $dlg_side \
         --process_english $process_english --process_translations $process_translations --do_translation $do_translation --retranslate_erred_examples $retranslate_erred_examples \
         --model_name_or_path $model_name_or_path --tgt_lang $tgt_lang \
         -- "$(requote "$@")

set -e
set -x
replace_config translate.yaml.in > translate.yaml

kubectl -n research delete job ${JOB_NAME} || true
kubectl apply -f translate.yaml
