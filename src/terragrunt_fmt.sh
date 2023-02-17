#!/bin/bash

function terragrunt_fmt {
	# Eliminate `-recursive` option for Terragrunt 0.11.x.
	fmt_recursive="-recursive"
	if hasPrefix "0.11" "${tf_version}"; then
		fmt_recursive=""
	fi

	# Gather the output of `terragrunt fmt`.
	echo "fmt: info: checking if Terragrunt files in ${tf_working_dir} are correctly formatted"
	fmt_output=$(${tf_binary} fmt -check=true -write=false -diff ${fmt_recursive} ${*} 2>&1)
	fmt_exit_code=${?}

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${fmt_exit_code} -eq 0 ]; then
		echo "fmt: info: Terragrunt files in ${tf_working_dir} are correctly formatted"
		echo "${fmt_output}"
		echo
		exit ${fmt_exit_code}
	fi

	# Exit code of 2 indicates a parse error. Print the output and exit.
	if [ ${fmt_exit_code} -eq 2 ]; then
		echo "fmt: error: failed to parse Terragrunt files"
		echo "${fmt_output}"
		echo
		exit ${fmt_exit_code}
	fi

	# Exit code of !0 and !2 indicates failure.
	echo "fmt: error: Terragrunt files in ${tf_working_dir} are incorrectly formatted"
	echo "${fmt_output}"
	echo
	echo "fmt: error: the following files in ${tf_working_dir} are incorrectly formatted"
	fmtFileList=$(${tf_binary} fmt -check=true -write=false -list ${fmt_recursive})
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

		fmt_comment_wrapper="#### \`${tf_binary} fmt\` Failed
${fmtComment}

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		fmt_comment_wrapper=$(stripColors "${fmt_comment_wrapper}")
		echo "fmt: info: creating JSON"
		fmt_payload=$(echo "${fmt_comment_wrapper}" | jq -R --slurp '{body: .}')
		fmt_comments_url=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "fmt: info: commenting on the pull request"
		echo "${fmt_payload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${fmt_comments_url}" >/dev/null
	fi

	# Write changes to branch
	echo "::set-output name=tf_actions_fmt_written::false"
	if [ "${tf_fmt_write}" == "1" ]; then
		echo "fmt: info: Terraform files in ${tf_working_dir} will be formatted"
		terraform fmt -write=true ${fmt_recursive} "${*}"
		fmt_exit_code=${?}
		echo "::set-output name=tf_actions_fmt_written::true"
	fi

	exit ${fmt_exit_code}
}
