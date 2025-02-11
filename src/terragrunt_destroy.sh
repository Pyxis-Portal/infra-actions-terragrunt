#!/bin/bash

function terragrunt_destroy {
	# Gather the output of `terragrunt destroy`.
	echo "destroy: info: destroying Terragrunt-managed infrastructure in ${tf_working_dir}"
	destroyOutput=$(${tf_binary} destroy -auto-approve -input=false ${*} 2>&1)
	destroyExitCode=${?}
	destroyCommentStatus="Failed"

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${destroyExitCode} -eq 0 ]; then
		echo "destroy: info: successfully destroyed Terragrunt-managed infrastructure in ${tf_working_dir}"
		echo "${destroyOutput}"
		echo
		destroyCommentStatus="Success"
	fi

	# Exit code of !0 indicates failure.
	if [ ${destroyExitCode} -ne 0 ]; then
		echo "destroy: error: failed to destroy Terragrunt configuration in ${tf_working_dir}"
		echo "${destroyOutput}"
		echo
	fi

	# Comment on the pull request if necessary.
	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		destroyCommentWrapper="#### \`${tf_binary} destroy\` ${destroyCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${destroyOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`*"

		destroyCommentWrapper=$(stripColors "${destroyCommentWrapper}")
		echo "destroy: info: creating JSON"
		destroyPayload=$(echo "${destroyCommentWrapper}" | jq -R --slurp '{body: .}')
		destroyCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "destroy: info: commenting on the pull request"
		echo "${destroyPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${destroyCommentsURL}" >/dev/null
	fi

	exit ${destroyExitCode}
}
