#! /usr/bin/env -S bash -euo pipefail

make_conda_env() {

    local env_name="${1}";

    # Remove the current conda env if called with `-f|--force`
    if echo "${@:2}" | grep -qE '(\-f|\-\-force)'; then
        rm -rf "$HOME/.conda/envs/${env_name}";
    fi

    local cuda_version="${CUDA_VERSION:-${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}}";
    cuda_version="$(echo "${cuda_version}" | cut -d'.' -f3 --complement)";

    local python_version="${PYTHON_VERSION:-}";

    if [ -z "${python_version}" ]; then
        python_version="$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f3 --complement)";
    fi

    local env_file_name="${env_name}.yml";
    local new_env_path="$(realpath -m /tmp/${env_file_name})";
    local old_env_path="$(realpath -m ~/.cache/${env_file_name})";

    local conda_noinstall=();
    local conda_env_yamls=();

    for lib in $(find ~ -maxdepth 1 -mindepth 1 -type d ! -name '.*' -exec basename {} \;); do
        if [ -f ~/"${lib}/dependencies.yaml" ]; then
            conda_env_yamls+=("/tmp/${lib}.yaml");
            conda_noinstall+=($(rapids-python-conda-pkg-names "${lib}"));
            /opt/conda/bin/rapids-dependency-file-generator \
                --file_key all \
                --output conda \
                --config ~/"${lib}/dependencies.yaml" \
                --matrix "arch=$(uname -m);cuda=${cuda_version};py=${python_version}" \
            > /tmp/${lib}.yaml;
        fi
    done

    # Generate a combined conda env yaml file.
    /opt/conda/bin/conda-merge ${conda_env_yamls[@]} \
      | grep -v '^name:' \
      | grep -v -P '^(.*?)\-(.*?)rapids-(.*?)$' \
      | grep -v -P '^(.*?)\-(.*?)(\.git\@[^(main|master)])(.*?)$' \
      | grep -v -P "^(.*?)\-(.*?)($(rapids-join-strings "|" ${conda_noinstall[@]}))(.*?)$" \
    > "${new_env_path}";

    rm ${conda_env_yamls[@]};

    # If the conda env doesn't exist, make one
    if ! conda info -e | grep -q "${env_name}"; then
        echo -e "Creating '${env_name}' conda environment\n" 1>&2;
        echo -e "Environment (${env_file_name}):\n" 1>&2;
        cat "${new_env_path}";
        echo "";

        mamba env create -n "${env_name}" -f "${new_env_path}";
    # If the conda env does exist but it's different from the one
    # generated by the current legate branch, print the diff between
    # the envs and update it
    elif ! diff -BNqw "${old_env_path}" "${new_env_path}" >/dev/null 2>&1; then
        echo -e "Updating '${env_name}' conda environment\n" 1>&2;
        echo -e "Environment (${env_file_name}):\n" 1>&2;

        # Print the diff to the console for debugging
        [ ! -f "${old_env_path}" ]                         \
         && cat "${new_env_path}"                          \
         || diff -BNyw "${old_env_path}" "${new_env_path}" \
         || true                                           \
         && echo "";

        # Update the current conda env + prune libs that were removed
        mamba env update -n "${env_name}" -f "${new_env_path}" --prune;
    fi

    cp -a "${new_env_path}" "${old_env_path}";
}

. /opt/conda/etc/profile.d/conda.sh;
. /opt/conda/etc/profile.d/mamba.sh;

make_conda_env "${DEFAULT_CONDA_ENV:-rapids}" "$@";

conda activate "${DEFAULT_CONDA_ENV:-rapids}" 2>/dev/null;
