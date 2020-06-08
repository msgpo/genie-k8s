#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "owner dataset_owner project task_name experiment dataset model pred_languages pred_set_name" "$@"
shift $n

set -e
set -x

IFS='+'; read -ra PLS <<<"$pred_languages"
echo "${PLS[@]}"

mkdir -p ./dataset

for lang in "${PLS[@]}"; do
  aws s3 sync s3://almond-research/${dataset_owner}/dataset/${project}/${experiment}/${dataset} ./dataset/ --exclude "*eval/*"  --exclude "*train*" --exclude "*" --include "*$lang*"
done

pwd
aws s3 cp --recursive s3://almond-research/${owner}/workdir/${project} ./ --exclude "*" --include '*.mk' --include '*.config' --include '*/schema.tt' --include 'Makefile'
mkdir -p ${experiment}/models
aws s3 sync --exclude 'iteration_*.pth' --exclude '*_optim.pth' --exclude "*failed_train/*" s3://almond-research/${owner}/models/${project}/${experiment}/${model}/ ${experiment}/models/${model}/

ls -al
mkdir -p tmp
export GENIE_TOKENIZER_ADDRESS=tokenizer.default.svc.cluster.local:8888
export TZ=America/Los_Angeles
IFS=' '
echo $pred_languages


for lang in "${PLS[@]}"; do
  mkdir -p $experiment/${pred_set_name}/${lang}
  make -B geniedir=/opt/genie-toolkit project=$project experiment=$experiment owner=$owner input_eval_server="./dataset/${lang}/${pred_set_name}.tsv" $experiment/${pred_set_name}/$model.results
  aws s3 sync $experiment/${pred_set_name}/ s3://almond-research/${owner}/workdir/${project}/$experiment/${pred_set_name}/${lang}/
  echo $lang
  cat $experiment/${pred_set_name}/$model.results
done
