#!/bin/bash
#
#. /opt/genie-toolkit/lib.sh
#
#parse_args "$0" "owner dataset_owner project task_name experiment dataset model" "$@"
#shift $n
#
#set -e
#set -x
#
##on_error () {
##  # on failure ship everything to s3
##  aws s3 sync . s3://almond-research/${owner}/models/${project}/${experiment}/${model}/failed_eval/   --exclude "*dataset/*"  --exclude "*cache/"
##  }
##trap on_error ERR
#
#
#pwd
#aws s3 sync s3://almond-research/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ${HOME}/dataset/ --exclude "*eval/*"
#
#
#mkdir -p ${experiment}/models
#
#aws s3 sync s3://almond-research/${owner}/models/${project}/${experiment}/${model}/ ${experiment}/models/${model}/ --exclude "iteration_*.pth" --exclude "*eval/*" --exclude "*failed_train/*" --exclude '*_optim.pth'
#
#mkdir -p "$HOME/cache"
#mkdir -p "$HOME/eval_dir"
#mkdir -p $HOME/dataset_linked/"${task_name//_/\/}"
#
#ln -s $HOME/dataset/* $HOME/dataset_linked/"${task_name//_/\/}"
#
#ls -R
#
#genienlp predict \
#  --data "$HOME/dataset_linked" \
#  --embeddings ${GENIENLP_EMBEDDINGS} \
#  --cache "$HOME/cache" \
#  --path "$HOME/${experiment}/models/${model}/" \
#  --eval_dir "$HOME/eval_dir" \
#  --skip_cache \
#  --tasks ${task_name} \
#  "$@"
#
#psn="${@: -1}"
#ls -R
#aws s3 sync $HOME/eval_dir s3://almond-research/${owner}/workdir/${project}/${experiment}/models/${model}/${dataset}/eval/${psn}


. /opt/genie-toolkit/lib.sh

parse_args "$0" "owner dataset_owner project task_name experiment dataset model pred_languages pred_set_name" "$@"
shift $n

set -e
set -x

mkdir -p ./dataset
aws s3 sync s3://almond-research/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ./dataset/ --exclude "*eval/*"

pwd
aws s3 cp --recursive s3://almond-research/${owner}/workdir/${project} ./ --exclude "*" --include '*.mk' --include '*.config' --include '*/schema.tt' --include 'Makefile'
mkdir -p ${experiment}/models
aws s3 sync --exclude 'iteration_*.pth' --exclude '*_optim.pth' --exclude "*failed_train/*" s3://almond-research/${owner}/models/${project}/${experiment}/${model}/ ${experiment}/models/${model}/

ls -al
mkdir -p tmp
export GENIE_TOKENIZER_ADDRESS=tokenizer.default.svc.cluster.local:8888
export TZ=America/Los_Angeles
echo $pred_languages
IFS='+'
read -ra PLS <<<"$pred_languages"
echo "${PLS[@]}"

for lang in "${PLS[@]}"; do
  mkdir -p $experiment/${pred_set_name}/${lang}
  make -B geniedir=/opt/genie-toolkit project=$project experiment=$experiment owner=$owner input_eval_server="./dataset/${lang}/${pred_set_name}.tsv" $experiment/${pred_set_name}/$model.results
  aws s3 sync $experiment/${pred_set_name}/ s3://almond-research/${owner}/workdir/${project}/$experiment/${pred_set_name}/${lang}/
  echo $lang
  cat $experiment/${pred_set_name}/$model.results
done
