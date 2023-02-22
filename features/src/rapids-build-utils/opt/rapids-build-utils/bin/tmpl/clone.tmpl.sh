#! /usr/bin/env -S bash -euo pipefail

clone_${NAME}() {
    if [[ ! -d ~/'${SRC_PATH}/.git' ]]; then

        local git_tag='${GIT_TAG}';
        local git_args="";
        git_args="${git_tag:+--branch $git_tag}";
        git_args="${git_args:-}";

        echo 'Cloning ${NAME}' 1>&2;

        ${GIT_HOST}-repo-clone \
            '${GIT_UPSTREAM}'  \
            '${GIT_REPO}'      \
            '${SRC_PATH}'      \
            "${git_args}"      \
            ;

        rapids-generate-scripts;

        rapids-make-vscode-workspace > ~/workspace.code-workspace;
    fi
}

clone_${NAME} "$@";
