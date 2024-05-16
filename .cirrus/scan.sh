#!/bin/bash
set -euo pipefail

export GIT_SHA1=${CIRRUS_CHANGE_IN_REPO}
export GITHUB_BASE_BRANCH=${CIRRUS_BASE_BRANCH:-}
export GITHUB_BRANCH=${CIRRUS_BRANCH}
export GITHUB_REPO=${CIRRUS_REPO_FULL_NAME}
export PULL_REQUEST=${CIRRUS_PR:-}

if [[ "${PULL_REQUEST}" ]] || [[ "${GITHUB_BRANCH}" == "master" ]]; then

  scanner_params=()

  if [[ "${GITHUB_BASE_BRANCH}" ]]; then
    git fetch origin "${GITHUB_BASE_BRANCH}"
  fi

  if [[ "${GITHUB_BRANCH}" == "master" ]]; then
    scanner_params+=("-Dsonar.qualitygate.wait=true")
  fi

  if [[ "${PULL_REQUEST}" ]]; then
    scanner_params+=("-Dsonar.analysis.prNumber=${PULL_REQUEST}")
  fi

  scanner_params+=(
    "-Dsonar.host.url=${SONAR_HOST_URL}"
    "-Dsonar.token=${SONAR_TOKEN}"
    "-Dsonar.analysis.pipeline=${CIRRUS_BUILD_ID}"
    "-Dsonar.analysis.repository=${GITHUB_REPO}"
    "-Dsonar.analysis.sha1=${GIT_SHA1}")
  sonar-scanner "${scanner_params[@]}"

fi