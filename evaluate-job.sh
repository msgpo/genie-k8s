#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "owner project experiment model" "$@"
shift $n

set -e
set -x

on_error () {
  # on failure ship everything to s3
  aws s3 sync . s3://almond-research/${owner}/models/${project}/${experiment}/${model}/failed_eval/   --exclude "*dataset/*"  --exclude "*cache/"
  }
trap on_error ERR


pwd
aws s3 sync s3://almond-research/${dataset_owner}/dataset/${project}/${experiment}/${dataset} $HOME/dataset/ --exclude "*eval/*"


mkdir -p ${experiment}/models

aws s3 sync s3://almond-research/${owner}/models/${project}/${experiment}/${model}/ ${experiment}/models/${model}/ --exclude "iteration_*.pth" --exclude '*_optim.pth' --exclude "*eval/*"

mkdir -p "$HOME/cache"
mkdir -p "$HOME/eval_dir"

ln -s "$HOME/dataset" "$HOME/dataset/${task_name}"

ls -R

genienlp predict \
  --data "$HOME/dataset" \
  --embeddings ${GENIENLP_EMBEDDINGS} \
  --cache "$HOME/cache" \
  --path "$HOME/${experiment}/models/${model}/" \
  --eval_dir "$HOME/eval_dir" \
  --skip_cache \
  --tasks ${task_name} \
  "$@"

ls -R
aws s3 sync $HOME/eval_dir s3://almond-research/${owner}/workdir/${project}/${experiment}/${model}/${dataset}/eval/


#aws s3 sync s3://almond-research/${owner}/workdir/${project} .
#mkdir -p ${experiment}/models
#aws s3 sync s3://almond-research/${owner}/models/${project}/${experiment}/${model}/ ${experiment}/models/${model}/
#
#ls -al
#mkdir -p tmp
#export GENIE_TOKENIZER_ADDRESS=tokenizer.default.svc.cluster.local:8888
#export TZ=America/Los_Angeles
#make geniedir=/opt/genie-toolkit "project=${project}" "experiment=${experiment}" "owner=${owner}" "model=${model}" "$@" evaluate
##cat model/*.results > ${experiment}-${dataset}-${model}.results
##aws s3 cp ${experiment}-${dataset}-${model}.results s3://almond-research/${owner}/${workdir}/
#make syncup
