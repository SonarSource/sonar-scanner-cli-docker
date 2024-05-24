#!/bin/bash

set -euo pipefail

declare -a args=()

add_env_var_as_env_prop() {
  if [[ -n "$1" ]]; then
    args+=("-D$2=$1")
  fi
}

# If there are certificates in /tmp/cacers we will import those into the systems truststore
if [[ -d /tmp/cacerts ]]; then
  # shellcheck disable=SC2312
  if [[ -n "$(ls -A /tmp/cacerts 2>/dev/null)" ]]; then
    for f in /tmp/cacerts/*
    do
      keytool -importcert -file "${f}" -alias "$(basename "${f}")" -keystore /etc/ssl/certs/java/cacerts -storepass changeit -trustcacerts -noprompt
    done
  fi
fi

# if nothing is passed, assume we want to run sonar-scanner
if [[ "$#" == 0 ]]; then
  set -- sonar-scanner
fi

# if first arg looks like a flag, assume we want to run sonar-scanner with flags
if [[ "${1#-}" != "${1}" ]] || ! command -v "${1}" > /dev/null; then
  set -- sonar-scanner "$@"
fi

if [[ "$1" = 'sonar-scanner' ]]; then
  add_env_var_as_env_prop "${SONAR_TOKEN:-}" "sonar.token"
  add_env_var_as_env_prop "${SONAR_PROJECT_BASE_DIR:-}" "sonar.projectBaseDir"
  add_env_var_as_env_prop "${SCANNER_WORKDIR_PATH:-}" "sonar.working.directory"
  if [[ ${#args[@]} -ne 0 ]]; then
    set -- sonar-scanner "${args[@]}" "${@:2}"
  fi
fi

exec "$@"
