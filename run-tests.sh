#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

port=9000
containers=()
network=$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 13 ; echo)

print_usage() {
  cat <<EOF
usage: $0 [IMAGE...]

examples:
       $0 "sonar-scanner-cli:4.1"
EOF
}

info() {
  echo "[info] $@"
}

warn() {
  echo "[warn] $@" >&2
}

fatal() {
  echo "[error] $@" >&2
  exit 1
}

require() {
  local prog missing=()
  for prog; do
    if ! type "$prog" &>/dev/null; then
      missing+=("$prog")
    fi
  done

  [[ ${#missing[@]} == 0 ]] || fatal "could not find required programs on the path: ${missing[@]}"
}

create_network() {
  docker network create "$network"
}

destroy_network() {
  docker network rm "$network"
}

wait_for_sonarqube() {
  local i web_up=no sonarqube_up=no

  for ((i = 0; i < 10; i++)); do
    info "waiting for web server to start ..."
    if curl -sI localhost:$port | grep '^HTTP/.* 200'; then
      web_up=yes
      break
    fi
    sleep 5
  done

  [[ $web_up == yes ]] || return 1

  for ((i = 0; i < 20; i++)); do
    info "waiting for sonarqube to be ready ..."
    if curl -s localhost:$port/api/system/status | grep '"status":"UP"'; then
      sonarqube_up=yes
      break
    fi
    sleep 10
  done

  [[ "$sonarqube_up" == yes ]]
}

test_scanner() {
  local scanner_finished_successfuly=no container_name
  container_name=$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 13 ; echo)
  echo "testing image $1 in container $container_name"

  git clone https://github.com/SonarSource/sonar-scanning-examples.git "$container_name"
  echo "sonar.projectKey=$container_name-test" >>"$(pwd)/$container_name/sonarqube-scanner/sonar-project.properties"
  echo "sonar.host.url=http://${containers[0]}:9000" >>"$(pwd)/$container_name/sonarqube-scanner/sonar-project.properties"

  docker run --network="$network" --name="$container_name" -it -v "$(pwd)/$container_name/sonarqube-scanner:/usr/src" "$1"
  containers+=("$container_name")
  docker wait "$container_name"
  echo "Container $container_name stopped."
  if docker logs "$container_name" | grep 'INFO: EXECUTION SUCCESS'; then
    scanner_finished_successfuly=yes
  fi

  rm -rf "$container_name"

  [[ "$scanner_finished_successfuly" == yes ]]
}

launch_sonarqube() {
  local container_name
  container_name=$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 13 ; echo)

  echo "Starting SonarQube in container $container_name in detached mode..."
  docker run --network="$network" --name="$container_name" -d -p $port:9000 sonarqube
  containers+=("$container_name")
  if wait_for_sonarqube ; then
    echo "SonarQube has been started."
  else
    echo "Failed to launch SonarQube"
    exit 1
  fi
}

clean_up() {
  echo "Stopping and removing containers: [${containers[*]}]"
  docker stop ${containers[*]}
  docker rm ${containers[*]}
  echo "Containers [${containers[*]}] have been stopped and removed."
}

require curl docker

for arg; do
  if [[ $arg == "-h" ]] || [[ $arg == "--help" ]]; then
    print_usage
    exit
  fi
done

if [[ $# == 0 ]]; then
  warn "at least one image as parameter is required"
  exit
fi

images=("$@")
results=()

create_network
launch_sonarqube

for image in "${images[@]}"; do
  if test_scanner "$image"; then
    results+=("success")
  else
    results+=("failure")
  fi
done

clean_up
destroy_network

failures=0
for ((i = 0; i < ${#images[@]}; i++)); do
  echo "${images[i]} => ${results[i]}"
  if [[ ${results[i]} != success ]]; then
    ((failures++)) || :
  fi
done

[[ $failures == 0 ]]
