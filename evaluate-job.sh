#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "s3_bucket owner project experiment dataset model model_owner pred_languages pred_set_name task_name" "$@"
shift $n

set -e
set -x

pwd
aws s3 cp --recursive  s3://geniehai/${owner}/workdir/${project} . --exclude "*" --include '*.mk' --include '*.config' --include '*/schema.tt' --include 'Makefile' --include '*database-map.tsv'


IFS='+'; read -ra PLS <<<"$pred_languages"; IFS=' '
echo "${PLS[@]}"

mkdir -p ./dataset

for lang in "${PLS[@]}"; do
  aws s3 sync s3://geniehai/${owner}/dataset/${project}/${experiment}/${dataset} ./dataset/ --exclude "*eval/*"  --exclude "*" --include "*$lang*" --include "*annotated.tsv" --exclude "*train*"
done

ls -al
mkdir -p tmp
export GENIE_TOKENIZER_ADDRESS=tokenizer.default.svc.cluster.local:8888
export TZ=America/Los_Angeles


for lang in "${PLS[@]}"; do
  mkdir -p $experiment/${pred_set_name}/${lang}
  if [[ "$task_name" == *"contextual"* || "$task_name" == *"dialog"* ]] ; then
      make -B geniedir=/opt/genie-toolkit experiment_dialog=$experiment pred_set_name=${pred_set_name} input_eval_server="./dataset/${lang}/${pred_set_name}.tsv" ${experiment}/${pred_set_name}/${model}.nlu.results
      for f in $experiment/${pred_set_name}/${model}.nlu.{results,debug} ; do
        aws s3 cp $f s3://geniehai/${owner}/workdir/${project}/${experiment}/${pred_set_name}/${lang}/
      done
      cat $experiment/${pred_set_name}/${model}.nlu.results
  else
    if [[ ! "$task_name" == *"multilingual"* ]] ; then
      lang=''
    fi
    make -B geniedir=/opt/genie-toolkit experiment=$experiment pred_set_name=${pred_set_name} input_eval_server="./dataset/${lang}/${pred_set_name}.tsv" ${experiment}/${pred_set_name}/${model}.results_single
      aws s3 cp $experiment/${pred_set_name}/${model}.results s3://geniehai/${owner}/workdir/${project}/${experiment}/${pred_set_name}/${lang}/
    cat $experiment/${pred_set_name}/${model}.results
  fi

done
