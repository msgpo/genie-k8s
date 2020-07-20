#!/bin/bash

. /opt/genie-toolkit/lib.sh

parse_args "$0" "s3_bucket owner dataset_owner project experiment model_name_or_path tgt_lang dlg_side do_translation process_translations process_english input_splits" "$@"
shift $n

set -e
set -x

export translation_arguments="$@"

translate() {
  genienlp run-paraphrase \
    --id_column 0 --input_column 1 --gold_column 1 \
    --input_file ${experiment}/${dlg_side}/en/aug-en/unquoted-qpis-marian/$f.tsv \
    --output_file ${experiment}/${dlg_side}/marian/${tgt_lang}/unquoted-qpis-translated/$f.tsv \
    --model_name_or_path ${model_name_or_path} \
    --tgt_lang ${tgt_lang} \
    --output_example_ids_too \
    --replace_qp \
    --skip_heuristics \
    --task translate \
    --return_attentions \
    $translation_arguments
}


translate_err(){
    genienlp run-paraphrase \
    --id_column 0 --input_column 1 --gold_column 1 \
    --input_file ${experiment}/${dlg_side}/en/aug-en/unquoted-qpis-marian/"$f"_errors.tsv \
    --output_file ${experiment}/${dlg_side}/marian/${tgt_lang}/unquoted-qpis-translated/"$f"_errors.tsv \
    --model_name_or_path ${model_name_or_path} \
    --tgt_lang ${tgt_lang} \
    --output_example_ids_too \
    --replace_qp \
    --skip_heuristics \
    --task translate \
    --return_attentions \
    $translation_arguments \
    --temperature 0.6
}


main() {
  # copy workdir makefiles over
  aws s3 cp --recursive s3://${s3_bucket}/${owner}/workdir/${project} ./ --exclude "*" \
    --include '*.mk' --include '*.config' --include '*/schema.tt' --include 'Makefile' --include '*.py' \
    --include "*${experiment}/${dlg_side}/en/*" --include "*${experiment}/${dlg_side}/marian/${tgt_lang}/*" --include '*dlg-shared-parameter-datasets*' --include "*dataset-dialogs/${experiment}/${dlg_side}/*"

  # generate english ref file if does not exist
  IFS='+'; read -ra input_splits_array <<<"$input_splits"; IFS=' '
  for f in "${input_splits_array[@]}"; do
    if ${process_english}; then
      make -B geniedir=/opt/genie-toolkit all_names=$f experiment_dialog=${experiment} process_data_dialogs || true
      aws s3 sync ./ s3://geniehai/${owner}/workdir/${project}/ --exclude '*' --include "*${experiment}/${dlg_side}*"
    fi

    # translate
    if ${do_translation}; then
      translate
      aws s3 sync ./ s3://geniehai/${owner}/workdir/${project}/ --exclude '*' --include '*unquoted-qpis-translated*'
    fi

    # further process the translated files
    if ${process_translations}; then
      make -B geniedir=/opt/genie-toolkit all_names=$f experiment_dialog=${experiment} skip_translation=true batch_translate_dlg_marian_${tgt_lang}
      aws s3 sync ./ s3://geniehai/${owner}/workdir/${project}/ --exclude '*' --include "*${experiment}/${dlg_side}*"
    fi

    # translate examples failed in previous rounds with more conservative temperatures (=0.6)
    if ${retranslate_erred_examples}; then
      make -B geniedir=/opt/genie-toolkit all_names=$f experiment_dialog=${experiment} skip_translation=true only_translate_erred_dlg_marian_${tgt_lang}
      translate_err()
    fi

  done
}

main
