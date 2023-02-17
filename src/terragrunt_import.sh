#!/bin/bash

function terragrunt_import {
	# Gather the output of `terragrunt import`.
	echo "import: info: importing Terragrunt configuration in ${tf_working_dir}"
	importOutput=$(${tf_binary} import -input=false ${*} 2>&1)
	importExitCode=${?}
	importCommentStatus="Failed"

	# Exit code of 0 indicates success with no changes. Print the output and exit.
	if [ ${importExitCode} -eq 0 ]; then
		echo "import: info: successfully imported Terragrunt configuration in ${tf_working_dir}"
		echo "${importOutput}"
		echo
		exit ${importExitCode}
	fi

	# Exit code of !0 indicates failure.
	if [ ${importExitCode} -ne 0 ]; then
		echo "import: error: failed to import Terragrunt configuration in ${tf_working_dir}"
		echo "${importOutput}"
		echo
	fi

	# Comment on the pull request if necessary.
	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${tf_comment}" == "1" ] && [ "${importCommentStatus}" == "Failed" ]; then
		importCommentWrapper="#### \`${tf_binary} import\` ${importCommentStatus}
<details><summary>Show Output</summary>

\`\`\`
${importOutput}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${tf_working_dir}\`, Workspace: \`${tf_workspace}\`*"

		importCommentWrapper=$(stripColors "${importCommentWrapper}")
		echo "import: info: creating JSON"
		importPayload=$(echo "${importCommentWrapper}" | jq -R --slurp '{body: .}')
		importCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
		echo "import: info: commenting on the pull request"
		echo "${importPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${importCommentsURL}" >/dev/null
	fi

	exit ${importExitCode}
}
