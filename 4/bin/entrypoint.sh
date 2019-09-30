#!/bin/bash

set -euo pipefail

declare -a args

add_env_var_as_env_prop() {
  if [ ! -z "$1" ]; then
    args+=("-D$2=$1")
  fi
}

add_env_var_as_env_prop "${SONAR_LOGIN:-}" "sonar.login"
add_env_var_as_env_prop "${SONAR_PASSWORD:-}" "sonar.password"

export SONAR_USER_HOME="$PWD/.sonar"

sonar-scanner "${args[@]}"
