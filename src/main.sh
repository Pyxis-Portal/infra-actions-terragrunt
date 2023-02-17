#!/bin/bash

function stripColors {
  echo "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

function hasPrefix {
  case ${2} in
  "${1}"*)
    true
    ;;
  *)
    false
    ;;
  esac
}

function parse_inputs {
  # Required inputs
  if [ "${INPUT_TF_ACTIONS_VERSION}" != "" ]; then
    tf_version=${INPUT_TF_ACTIONS_VERSION}
  else
    echo "Input terraform_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TG_ACTIONS_VERSION}" != "" ]; then
    tg_version=${INPUT_TG_ACTIONS_VERSION}
  else
    echo "Input terragrunt_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TF_ACTIONS_SUBCOMMAND}" != "" ]; then
    tf_subcommand=${INPUT_TF_ACTIONS_SUBCOMMAND}
  else
    echo "Input terraform_subcommand cannot be empty"
    exit 1
  fi

  # Optional inputs
  tf_working_dir="."
  if [[ -n "${INPUT_TF_ACTIONS_WORKING_DIR}" ]]; then
    tf_working_dir=${INPUT_TF_ACTIONS_WORKING_DIR}
  fi

  tf_binary="terragrunt"
  if [[ -n "${INPUT_TF_ACTIONS_BINARY}" ]]; then
    tf_binary=${INPUT_TF_ACTIONS_BINARY}
  fi

  tf_comment=0
  if [ "${INPUT_TF_ACTIONS_COMMENT}" == "1" ] || [ "${INPUT_TF_ACTIONS_COMMENT}" == "true" ]; then
    tf_comment=1
  fi

  tf_cli_credentials_hostname=""
  if [ "${INPUT_TF_ACTIONS_CLI_CREDENTIALS_HOSTNAME}" != "" ]; then
    tf_cli_credentials_hostname=${INPUT_TF_ACTIONS_CLI_CREDENTIALS_HOSTNAME}
  fi

  tf_cli_credentials_token=""
  if [ "${INPUT_TF_ACTIONS_CLI_CREDENTIALS_TOKEN}" != "" ]; then
    tf_cli_credentials_token=${INPUT_TF_ACTIONS_CLI_CREDENTIALS_TOKEN}
  fi

  tf_fmt_write=0
  if [ "${INPUT_TF_ACTIONS_FMT_WRITE}" == "1" ] || [ "${INPUT_TF_ACTIONS_FMT_WRITE}" == "true" ]; then
    tf_fmt_write=1
  fi

  tf_workspace="default"
  if [ -n "${TF_WORKSPACE}" ]; then
    tf_workspace="${TF_WORKSPACE}"
  fi
}

function configure_cli_credentials {
  if [[ ! -f "${HOME}/.terraformrc" ]] && [[ "${tf_cli_credentials_token}" != "" ]]; then
    cat >${HOME}/.terraformrc <<EOF
credentials "${tf_cli_credentials_hostname}" {
  token = "${tf_cli_credentials_token}"
}
EOF
  fi
}

function install_terraform {
  if [[ "${tf_version}" == "latest" ]]; then
    echo "Checking the latest version of Terraform"
    tf_version=$(curl -sL https://releases.hashicorp.com/terraform/index.json | jq -r '.versions[].version' | grep -v '[-].*' | sort -rV | head -n 1)

    if [[ -z "${tf_version}" ]]; then
      echo "Failed to fetch the latest version"
      exit 1
    fi
  fi

  url="https://releases.hashicorp.com/terraform/${tf_version}/terraform_${tf_version}_linux_amd64.zip"

  echo "Downloading Terraform v${tf_version}"
  curl -s -S -L -o /tmp/terraform_${tf_version} ${url}
  if [ "${?}" -ne 0 ]; then
    echo "Failed to download Terraform v${tf_version}"
    exit 1
  fi
  echo "Successfully downloaded Terraform v${tf_version}"

  echo "Unzipping Terraform v${tf_version}"
  unzip -d /usr/local/bin /tmp/terraform_${tf_version} &>/dev/null
  if [ "${?}" -ne 0 ]; then
    echo "Failed to unzip Terraform v${tf_version}"
    exit 1
  fi
  echo "Successfully unzipped Terraform v${tf_version}"
}

function install_terragrunt {
  if [[ "${tg_version}" == "latest" ]]; then
    echo "Checking the latest version of Terragrunt"
    latestURL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/gruntwork-io/terragrunt/releases/latest)
    tg_version=${latestURL##*/}

    if [[ -z "${tg_version}" ]]; then
      echo "Failed to fetch the latest version"
      exit 1
    fi
  fi

  url="https://github.com/gruntwork-io/terragrunt/releases/download/${tg_version}/terragrunt_linux_amd64"

  echo "Downloading Terragrunt ${tg_version}"
  curl -s -S -L -o /tmp/terragrunt ${url}
  if [ "${?}" -ne 0 ]; then
    echo "Failed to download Terragrunt ${tg_version}"
    exit 1
  fi
  echo "Successfully downloaded Terragrunt ${tg_version}"

  echo "Moving Terragrunt ${tg_version} to PATH"
  chmod +x /tmp/terragrunt
  mv /tmp/terragrunt /usr/local/bin/terragrunt
  if [ "${?}" -ne 0 ]; then
    echo "Failed to move Terragrunt ${tg_version}"
    exit 1
  fi
  echo "Successfully moved Terragrunt ${tg_version}"
}

function main {
  # Source the other files to gain access to their functions
  script_dir=$(dirname ${0})
  source ${script_dir}/terragrunt_fmt.sh
  source ${script_dir}/terragrunt_init.sh
  source ${script_dir}/terragrunt_validate.sh
  source ${script_dir}/terragrunt_plan.sh
  source ${script_dir}/terragrunt_apply.sh
  source ${script_dir}/terragrunt_output.sh
  source ${script_dir}/terragrunt_import.sh
  source ${script_dir}/terragrunt_taint.sh
  source ${script_dir}/terragrunt_destroy.sh
  source ${script_dir}/terragrunt_hclfmt.sh

  parse_inputs
  configure_cli_credentials
  install_terraform
  cd ${GITHUB_WORKSPACE}/${tf_working_dir}

  case "${tf_subcommand}" in
  hclfmt)
    install_terragrunt
    terragrunt_hcl_fmt ${*}
    ;;
  fmt)
    install_terragrunt
    terragrunt_fmt ${*}
    ;;
  init)
    install_terragrunt
    terragrunt_init ${*}
    ;;
  validate)
    install_terragrunt
    terragrunt_validate ${*}
    ;;
  plan)
    install_terragrunt
    terragrunt_plan ${*}
    ;;
  apply)
    install_terragrunt
    terragrunt_apply ${*}
    ;;
  output)
    install_terragrunt
    terragrunt_output ${*}
    ;;
  import)
    install_terragrunt
    terragrunt_import ${*}
    ;;
  taint)
    install_terragrunt
    terragrunt_taint ${*}
    ;;
  destroy)
    install_terragrunt
    terragrunt_destroy ${*}
    ;;
  *)
    echo "Error: Must provide a valid value for terragrunt_subcommand"
    exit 1
    ;;
  esac
}

main "${*}"
