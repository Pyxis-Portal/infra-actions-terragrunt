#!/bin/bash

function terragrunt_apply {
	# Gather the output of `terragrunt apply`.
	echo "apply: info: applying Terragrunt configuration in ${tf_working_dir}"
	applyOutput=$(${tf_binary} apply -auto-approve -input=false ${*} 2>&1)
	applyExitCode=${?}
	applyCommentStatus="Failed"

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${applyExitCode} -eq 0 ]; then
		echo "apply: info: successfully applied Terragrunt configuration in ${tf_working_dir}"
		echo "${applyOutput}"
		echo
		applyCommentStatus="Success"
	fi

	# Exit code of !0 indicates failure.
	if [ ${applyExitCode} -ne 0 ]; then
		echo "apply: error: failed to apply Terragrunt configuration in ${tf_working_dir}"
		echo "${applyOutput}"
		echo
	fi

	# Comment on the pull request if necessary.
	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		applyCommentWrapper="#### \`${tf_binary} apply\` ${applyCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${applyOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		applyCommentWrapper=$(stripColors "${applyCommentWrapper}")
		echo "apply: info: creating JSON"
		applyPayload=$(echo "${applyCommentWrapper}" | jq -R --slurp '{body: .}')
		applyCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "apply: info: commenting on the pull request"
		echo "${applyPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${applyCommentsURL}" >/dev/null
	fi

	exit ${applyExitCode}
}
