#!/bin/bash

function terragrunt_hcl_fmt {
	# Gather the output of `terragrunt hclfmt`.
	echo "fmt: info: checking if Terragrunt HCL files in ${tf_working_dir} are correctly formatted"
	if [ ${tf_binary} != "terragrunt" ]; then
		echo "skipping formatting HCL files"
		exit 0
	fi

	fmtOutput=$(${tf_binary} hclfmt --terragrunt-check)
	fmtExitCode=${?}

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${fmtExitCode} -eq 0 ]; then
		echo "hclfmt: info: Terragrunt files in ${tf_working_dir} are correctly formatted"
		echo "${fmtOutput}"
		echo
		exit ${fmtExitCode}
	else
		echo "hclfmt: error: failed to format Terragrunt files"
		echo "${fmtOutput}"
	fi

	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		fmtCommentWrapper="#### \`${tf_binary} hclfmt\` Failed:
# echo "FMT OUTPUT ${fmtOutput}"
*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		fmtCommentWrapper=$(stripColors "${fmtCommentWrapper}")
		echo "fmt: info: creating JSON"
		fmtPayload=$(echo "${fmtCommentWrapper}" | jq -R --slurp '{body: .}')
		fmtCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "fmt: info: commenting on the pull request"
		echo "${fmtPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${fmtCommentsURL}" >/dev/null
	fi

	# Write changes to branch
	echo "tf_actions_fmt_written=false" >>$GITHUB_OUTPUT
	if [ "${tf_fmt_write}" == "1" ]; then
		echo "fmt: info: Terraform files in ${tf_working_dir} will be formatted"
		terraform fmt -write=true ${fmtRecursive} "${*}"
		fmtExitCode=${?}
		echo "tf_actions_fmt_written=true" >>$GITHUB_OUTPUT
	fi

	exit ${fmtExitCode}
}
