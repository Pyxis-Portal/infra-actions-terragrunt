#!/bin/bash

function terragrunt_taint {
	# Gather the output of `terragrunt taint`.
	echo "taint: info: tainting terragrunt configuration in ${tf_working_dir}"
	#taintOutput=$(terragrunt taint ${*} 2>&1)
	taintOutput=$(for resource in ${*}; do ${tf_binary} taint -allow-missing $resource; done 2>&1)
	taintExitCode=${?}
	taintCommentStatus="Failed"

	# Exit code of 0 indicates success with no changes. Print the output and exit.
	if [ ${taintExitCode} -eq 0 ]; then
		taintCommentStatus="Success"
		echo "taint: info: successfully tainted Terragrunt configuration in ${tf_working_dir}"
		echo "${taintOutput}"
		echo
		exit ${taintExitCode}
	fi

	# Exit code of !0 indicates failure.
	if [ ${taintExitCode} -ne 0 ]; then
		echo "taint: error: failed to taint Terragrunt configuration in ${tf_working_dir}"
		echo "${taintOutput}"
		echo
	fi

	# Comment on the pull request if necessary.
	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		taintCommentWrapper="#### \`${tf_binary} taint\` ${taintCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${taintOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		taintCommentWrapper=$(stripColors "${taintCommentWrapper}")
		echo "taint: info: creating JSON"
		taintPayload=$(echo "${taintCommentWrapper}" | jq -R --slurp '{body: .}')
		taintCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "taint: info: commenting on the pull request"
		echo "${taintPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${taintCommentsURL}" >/dev/null
	fi

	exit ${taintExitCode}
}
