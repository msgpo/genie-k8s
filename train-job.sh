#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "s3_bucket owner dataset_owner task_name project experiment dataset model load_from train_languages eval_languages" "$@"
shift $n

set -e
set -x

modeldir="$HOME/models/$model"
mkdir -p "$modeldir"

if ! test  ${load_from} = 'None' ; then
	aws s3 sync ${load_from}/ "$modeldir"/ --exclude "iteration_*.pth" --exclude "*eval/*"  --exclude "*.log"
fi

IFS='+' ; read -ra TLS <<<"$train_languages"; IFS=' '
echo "${TLS[@]}"
IFS='+'; read -ra ELS <<<"$eval_languages"; IFS=' '
echo "${ELS[@]}"

rm -fr "$modeldir/dataset"
rm -fr "$modeldir/cache"
mkdir -p "$modeldir/cache"

if [[ "$task_name" == *"multilingual"* ]] ; then
  # only sync the files needed for this training
  for lang in "${TLS[@]}" "${ELS[@]}" ; do
    aws s3 sync s3://${s3_bucket}/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ${HOME}/dataset/ --exclude "*" --include "*$lang*"
  done
  mkdir -p $modeldir/dataset/almond/multilingual
  ln -s ${HOME}/dataset/* $modeldir/dataset/almond/multilingual
else
  aws s3 sync --exclude "synthetic*.txt" s3://${s3_bucket}/${dataset_owner}/dataset/${project}/${experiment}/${dataset} dataset/
  mkdir -p $modeldir/dataset/almond/multilingual
  ln -s ${HOME}/dataset/* $modeldir/dataset/almond
fi

ln -s $modeldir /home/genie-toolkit/current
mkdir -p "/shared/tensorboard/${project}/${experiment}/${owner}/${model}"

#on_error () {
#  # on failure ship everything to s3
#  aws s3 sync $modeldir/ s3://almond-research/${owner}/models/${experiment}/${model}/failed_train/
#}
#trap on_error ERR

# print directory tree
ls -R

genienlp train \
  --data "$modeldir/dataset" \
  --embeddings ${GENIENLP_EMBEDDINGS} \
  --save "$modeldir" \
  --tensorboard_dir "/shared/tensorboard/${project}/${experiment}/${owner}/${model}" \
  --cache "$modeldir/cache" \
  --train_tasks ${task_name} \
  --preserve_case \
  --save_every 1000 \
  --log_every 100 \
  --val_every 1000 \
  --train_languages $train_languages \
  --eval_languages $eval_languages \
  --exist_ok \
  --skip_cache \
  "$@" 
  
rm -fr "$modeldir/cache"
rm -fr "$modeldir/dataset"
aws s3 sync ${modeldir}/ s3://${s3_bucket}/${owner}/models/${project}/${experiment}/${model}
