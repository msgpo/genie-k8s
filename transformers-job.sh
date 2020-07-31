#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "s3_bucket owner dataset_owner project experiment dataset model wandb_key num_gpus src_lang tgt_lang" "$@"
shift $n

set -e
set -x

# run all commands within this directory
cd /opt/transformers
cd examples/seq2seq

export PYTHONPATH="../":"${PYTHONPATH}"
export WANDB_API_KEY=$wandb_key

mkdir -p ./${dataset}
aws s3 sync s3://${s3_bucket}/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ./${dataset}

# do not create this directory
# finetune script will do
output_dir="./${project}_${experiment}"

# finetune mbart cc25
python3 finetune.py \
          --do_train --do_predict \
          --learning_rate 3e-5 \
          --val_check_interval 0.25 \
          --adam_eps 1e-06 \
          --num_train_epochs 6 \
          --src_lang $src_lang \
          --tgt_lang $tgt_lang \
          --data_dir ./${dataset}/ \
          --max_source_length 200 --max_target_length 200 --val_max_target_length 200 --test_max_target_length 200 \
          --train_batch_size 4 --eval_batch_size 4 --gradient_accumulation_steps 2 \
          --task translation \
          --warmup_steps 500 \
          --freeze_embeds \
          --early_stopping_patience 4 \
          --model_name_or_path facebook/mbart-large-cc25 \
          --output_dir $output_dir \
          --gpus $num_gpus \
          "$@"

aws s3 sync $output_dir/ s3://${s3_bucket}/${owner}/models/${project}/${experiment}/${model}



