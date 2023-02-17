#!/bin/bash

function terragrunt_fmt {
	# Eliminate `-recursive` option for Terragrunt 0.11.x.
	fmtRecursive="-recursive"
	if hasPrefix "0.11" "${tf_version}"; then
		fmtRecursive=""
	fi

	# Gather the output of `terragrunt fmt`.
	echo "fmt: info: checking if Terragrunt files in ${tf_working_dir} are correctly formatted"
	fmtOutput=$(${tf_binary} fmt -check=true -write=false -diff ${fmtRecursive} ${*} 2>&1)
	fmtExitCode=${?}

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${fmtExitCode} -eq 0 ]; then
		echo "fmt: info: Terragrunt files in ${tf_working_dir} are correctly formatted"
		echo "${fmtOutput}"
		echo
		exit ${fmtExitCode}
	fi

	# Exit code of 2 indicates a parse error. Print the output and exit.
	if [ ${fmtExitCode} -eq 2 ]; then
		echo "fmt: error: failed to parse Terragrunt files"
		echo "${fmtOutput}"
		echo
		exit ${fmtExitCode}
	fi

	# Exit code of !0 and !2 indicates failure.
	echo "fmt: error: Terragrunt files in ${tf_working_dir} are incorrectly formatted"
	echo "${fmtOutput}"
	echo
	echo "fmt: error: the following files in ${tf_working_dir} are incorrectly formatted"
	fmtFileList=$(${tf_binary} fmt -check=true -write=false -list ${fmtRecursive})
	echo "${fmtFileList}"
	echo

	# Comment on the pull request if necessary.
	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		fmtComment=""
		for file in ${fmtFileList}; do
			fmtFileDiff=$(${tf_binary} fmt -check=true -write=false -diff "${file}" | sed -n '/@@.*/,//{/@@.*/d;p}')
			fmtComment="${fmtComment}
<details><summary><code>${tf_working_dir}/${file}</code></summary>

\`\`\`diff
${fmtFileDiff}
\`\`\`

</details>"

		done

		fmtCommentWrapper="#### \`${tf_binary} fmt\` Failed
${fmtComment}

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		fmtCommentWrapper=$(stripColors "${fmtCommentWrapper}")
		echo "fmt: info: creating JSON"
		fmtPayload=$(echo "${fmtCommentWrapper}" | jq -R --slurp '{body: .}')
		fmtCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "fmt: info: commenting on the pull request"
		echo "${fmtPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${fmtCommentsURL}" >/dev/null
	fi

	# Write changes to branch
	echo "::set-output name=tf_actions_fmt_written::false"
	if [ "${tf_fmt_write}" == "1" ]; then
		echo "fmt: info: Terraform files in ${tf_working_dir} will be formatted"
		terraform fmt -write=true ${fmtRecursive} "${*}"
		fmtExitCode=${?}
		echo "::set-output name=tf_actions_fmt_written::true"
	fi

	exit ${fmtExitCode}
}
