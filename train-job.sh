#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "owner dataset_owner task_name project experiment dataset model load_from train_languages eval_languages" "$@"
shift $n

set -e
set -x

modeldir="$HOME/models/$model"
mkdir -p "$modeldir"

if ! test  ${load_from} = 'None' ; then
	aws s3 sync ${load_from} "$modeldir"/ --exclude "iteration_*.pth" --exclude "*eval/*"  --exclude "*.log"
fi

echo $train_languages
IFS='+'; read -ra TLS <<<"$train_languages"
echo "${TLS[@]}"

for lang in "${TLS[@]}"; do
  aws s3 sync s3://almond-research/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ${HOME}/dataset/ --exclude "*" --include "*$lang*"
done

echo $eval_languages
IFS='+'; read -ra ELS <<<"$eval_languages"
echo "${ELS[@]}"

for lang in "${ELS[@]}"; do
  aws s3 sync s3://almond-research/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ${HOME}/dataset/ --exclude "*" --include "*$lang*"
done

IFS=' '

rm -fr "$modeldir/dataset"
mkdir -p "$modeldir/dataset/"${task_name//_/\/}""
rm -fr "$modeldir/cache"
mkdir -p "$modeldir/cache"
ln -s "$HOME/dataset" "$modeldir/dataset/almond"
ln -s ${HOME}/dataset/* $modeldir/dataset/"${task_name//_/\/}"
ln -s $modeldir /home/genie-toolkit/current
mkdir -p "/shared/tensorboard/${project}/${experiment}/${owner}/${dataset}/${model}/"
export tensorboard_dir="/shared/tensorboard/${project}/${experiment}/${owner}/${dataset}/${model}/"

on_error () {
  # on failure ship everything to s3
  aws s3 sync $modeldir/ s3://almond-research/${owner}/models/${project}/${experiment}/${model}/failed_train/ --exclude "*dataset/*"  --exclude "*cache/"
}
trap on_error ERR

ls -R

genienlp train \
  --data "$modeldir/dataset" \
  --embeddings ${GENIENLP_EMBEDDINGS} \
  --save "$modeldir" \
  --tensorboard_dir $tensorboard_dir \
  --cache "$modeldir/cache" \
  --train_tasks ${task_name} \
  --preserve_case \
  --save_every 1000 \
  --log_every 100 \
  --val_every 1000 \
  --exist_ok \
  --skip_cache \
  --train_languages $train_languages \
  --eval_languages $eval_languages \
  "$@" 

rm -fr "$modeldir/cache"
rm -fr "$modeldir/dataset"
aws s3 sync ${modeldir}/ s3://almond-research/${owner}/models/${project}/${experiment}/${model}
