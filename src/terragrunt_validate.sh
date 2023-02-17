#!/bin/bash

function terragrunt_validate {
	# Gather the output of `terragrunt validate`.
	echo "validate: info: validating Terragrunt configuration in ${tf_working_dir}"
	validateOutput=$(${tf_binary} validate ${*} 2>&1)
	validateExitCode=${?}

	# Exit code of 0 indicates success. Print the output and exit.
	if [ ${validateExitCode} -eq 0 ]; then
		echo "validate: info: successfully validated Terragrunt configuration in ${tf_working_dir}"
		echo "${validateOutput}"
		echo
		exit ${validateExitCode}
	fi

	# Exit code of !0 indicates failure.
	echo "validate: error: failed to validate Terragrunt configuration in ${tf_working_dir}"
	echo "${validateOutput}"
	echo

	# Comment on the pull request if necessary.
	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ]; then
		validateCommentWrapper="#### \`${tf_binary} validate\` Failed

\`\`\`
${validateOutput}
\`\`\`

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		validateCommentWrapper=$(stripColors "${validateCommentWrapper}")
		echo "validate: info: creating JSON"
		validatePayload=$(echo "${validateCommentWrapper}" | jq -R --slurp '{body: .}')
		validateCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "validate: info: commenting on the pull request"
		echo "${validatePayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${validateCommentsURL}" >/dev/null
	fi

	exit ${validateExitCode}
}
