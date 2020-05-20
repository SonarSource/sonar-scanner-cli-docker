#!/bin/bash

set -euo pipefail

declare -a args=()

add_env_var_as_env_prop() {
  if [ "$1" ]; then
    args+=("-D$2=$1")
  fi
}

# if nothing is passed, assume we want to run sonar-scanner
if [ "$#" == 0 ]; then
  set -- sonar-scanner
fi

# if first arg looks like a flag, assume we want to run sonar-scanner with flags
if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ]; then
  set -- sonar-scanner "$@"
fi

if [[ "$1" = 'sonar-scanner' ]]; then
    chown -R "$(id -u):$(id -g)" "${PWD}" "${SONAR_USER_HOME}" 2>/dev/null || :
    chmod -R 700 "${PWD}" "${SONAR_USER_HOME}" 2>/dev/null || :

    # Allow the container to be started with `--user`
    if [[ "$(id -u)" = '0' ]]; then
        chown -R scanner-cli:scanner-cli "${PWD}" "${SONAR_USER_HOME}"
        exec su-exec scanner-cli "$0" "$@"
    fi

  if mkdir -p "${SONAR_USER_HOME}/.sonar" > /dev/null 2>&1 ; then
    add_env_var_as_env_prop "${SONAR_LOGIN:-}" "sonar.login"
    add_env_var_as_env_prop "${SONAR_PASSWORD:-}" "sonar.password"
    add_env_var_as_env_prop "${SONAR_PROJECT_BASE_DIR:-}" "sonar.projectBaseDir"
    if [ ${#args[@]} -ne 0 ]; then
      set -- sonar-scanner "${args[@]}" "${@:2}"
    fi
  else
    echo "Cannot write to ${SONAR_USER_HOME}/.sonar. Please make sure you have set appriopriate permissions for all used volumes."
    exit 1
  fi
fi

exec "$@"
