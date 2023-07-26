#!/bin/bash

set -euo pipefail

declare -a args=()

add_env_var_as_env_prop() {
  if [ "$1" ]; then
    args+=("-D$2=$1")
  fi
}

# If there are certificates in /tmp/cacers we will import those into the systems truststore
if [ -d /tmp/cacerts ]; then
  if [ "$(ls -A /tmp/cacerts)" ]; then
    for f in /tmp/cacerts/*
    do
      keytool -importcert -file "${f}" -alias "$(basename ${f})" -keystore /usr/lib/jvm/default-jvm/jre/lib/security/cacerts -storepass changeit -trustcacerts -noprompt
    done
  fi
fi

# if nothing is passed, assume we want to run sonar-scanner
if [[ "$#" == 0 ]]; then
  set -- sonar-scanner
fi

# if first arg looks like a flag, assume we want to run sonar-scanner with flags
if [[ "${1#-}" != "${1}" ]] || [[ -z "$(command -v "${1}")" ]]; then
  set -- sonar-scanner "$@"
fi

if [[ "$1" = 'sonar-scanner' ]]; then
  add_env_var_as_env_prop "${SONAR_LOGIN:-}" "sonar.login"
  add_env_var_as_env_prop "${SONAR_PASSWORD:-}" "sonar.password"
  add_env_var_as_env_prop "${SONAR_PROJECT_BASE_DIR:-}" "sonar.projectBaseDir"
  if [ ${#args[@]} -ne 0 ]; then
    set -- sonar-scanner "${args[@]}" "${@:2}"
  fi
fi

exec "$@"
