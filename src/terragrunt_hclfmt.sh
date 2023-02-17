#!/bin/bash

function terragrunt_hcl_fmt {
	# Gather the output of `terragrunt hclfmt`.
	echo "fmt: info: checking if Terragrunt HCL files in ${tf_working_dir} are correctly formatted"
	if [ ${tf_binary} != "terragrunt" ]; then
		echo "skipping formatting HCL files"
		exit 0
	fi

	fmt_output=$(${tf_binary} hclfmt --terragrunt-check)
	fmt_exit_code=${?}

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${fmt_exit_code} -eq 0 ]; then
		echo "hclfmt: info: Terragrunt files in ${tf_working_dir} are correctly formatted"
		echo "${fmt_output}"
		echo
		exit ${fmt_exit_code}
	else
		echo "hclfmt: error: failed to format Terragrunt files"
		echo "${fmt_output}"
	fi

	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		fmt_comment_wrapper="#### \`${tf_binary} hclfmt\` Failed:
# echo "FMT OUTPUT ${fmt_output}"
*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		fmt_comment_wrapper=$(stripColors "${fmt_comment_wrapper}")
		echo "fmt: info: creating JSON"
		fmt_payload=$(echo "${fmt_comment_wrapper}" | jq -R --slurp '{body: .}')
		fmt_comments_url=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "fmt: info: commenting on the pull request"
		echo "${fmt_payload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${fmt_comments_url}" >/dev/null
	fi

	# Write changes to branch
	echo "tf_actions_fmt_written=false" >>$GITHUB_OUTPUT
	if [ "${tf_fmt_write}" == "1" ]; then
		echo "fmt: info: Terraform files in ${tf_working_dir} will be formatted"
		terraform fmt -write=true ${fmt_recursive} "${*}"
		fmt_exit_code=${?}
		echo "tf_actions_fmt_written=true" >>$GITHUB_OUTPUT
	fi

	exit ${fmt_exit_code}
}
