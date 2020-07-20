#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "s3_bucket owner project experiment dataset model model_owner pred_languages pred_set_name" "$@"
shift $n

set -e
set -x

# on_error () {
 	# on failure ship everything to s3
# 	aws s3 sync . s3://geniehai/${owner}/models/${project}/${experiment}/${model}/failed_eval/
# }
# trap on_error ERR

pwd
aws s3 cp --recursive  s3://${s3_bucket}/${owner}/workdir/${project} . --exclude "*" --include '*.mk' --include '*.config' --include '*/schema.tt' --include 'Makefile' --include '*database-map.tsv'


IFS='+'; read -ra PLS <<<"$pred_languages"; IFS=' '
echo "${PLS[@]}"

mkdir -p ./dataset

for lang in "${PLS[@]}"; do
  aws s3 sync s3://geniehai/${owner}/dataset/${project}/${experiment}/${dataset} ./dataset/ --exclude "*eval/*"  --exclude "*train*" --exclude "*" --include "*$lang*" --include "*annotated.tsv"
done

ls -al
mkdir -p tmp
export GENIE_TOKENIZER_ADDRESS=tokenizer.default.svc.cluster.local:8888
export TZ=America/Los_Angeles


for lang in "${PLS[@]}"; do
  mkdir -p $experiment/${pred_set_name}/${lang}
  make -B geniedir=/opt/genie-toolkit experiment_dialog=$experiment experiment=$experiment pred_set_name=${pred_set_name} input_eval_server="./dataset/${lang}/${pred_set_name}.tsv" ${experiment}/${pred_set_name}/${model}.nlu.results
  for f in $experiment/${pred_set_name}/${model}.nlu.{results,debug} ; do
    aws s3 cp $f s3://${s3_bucket}/${owner}/workdir/${project}/${experiment}/${pred_set_name}/${lang}/
  done
  cat $experiment/${pred_set_name}/${model}.nlu.results
done
