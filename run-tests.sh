#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

generate_id() {
  LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 13 2>/dev/null
}

port=9000
containers=()
sonarqube_container_name="it-sonarqube"
network="it-network"

print_usage() {
  cat <<EOF
usage: $0 [IMAGE...]

examples:
       $0 "sonar-scanner-cli:4.1"
EOF
}

info() {
  echo "[info] $*"
}

warn() {
  echo "[warn] $*" >&2
}

fatal() {
  echo "[error] $*" >&2
  exit 1
}

require() {
  local prog missing=()
  for prog; do
    if ! type "$prog" &>/dev/null; then
      missing+=("$prog")
    fi
  done

  [[ ${#missing[@]} == 0 ]] || fatal "could not find required programs on the path: ${missing[*]}"
}

create_network() {
  docker network create "$network" || true
}

destroy_network() {
  docker network rm "$network"
}

wait_for_sonarqube() {
  local i web_up=no sonarqube_up=no

  for ((i = 0; i < 10; i++)); do
    info "waiting for web server to start ..."
    if curl -sI "localhost:$port" | grep '^HTTP/.* 200'; then
      web_up=yes
      break
    fi
    sleep 5
  done

  [[ $web_up == yes ]] || return 1

  for ((i = 0; i < 20; i++)); do
    info "waiting for sonarqube to be ready ..."
    if curl -s "localhost:$port/api/system/status" | grep '"status":"UP"'; then
      sonarqube_up=yes
      break
    fi
    sleep 10
  done

  [[ "$sonarqube_up" == yes ]]
}

create_scanner_cache() {
  local tmpDir=""
  tmpDir="$(mktemp --directory)"
  scanner_cache="$tmpDir/.sonar"
  mkdir -p "$scanner_cache"
  info ".sonar dir created: $scanner_cache"
}

test_scanner() {
  local scanner_finished_successfuly=no container_name
  local image="$1"
  container_name=$(generate_id)
  info "testing image $1 in container $container_name"

  scanner_props_location="$PWD/target_repository/sonarqube-scanner/sonar-project.properties"
  echo "sonar.projectKey=$container_name-test" >> "$scanner_props_location"
  echo "sonar.login=admin" >> "$scanner_props_location"
  echo "sonar.password=admin" >> "$scanner_props_location"
  
  docker run --network="$network" \
     --name="$container_name" \
     --user="$(id -u):$(id -g)" \
     -v "$PWD/target_repository/sonarqube-scanner:/usr/src" -v "${scanner_cache}:/usr/.sonar" \
     --env SONAR_HOST_URL="http://${sonarqube_container_name}:9000" \
     --env SONAR_USER_HOME="/usr/.sonar" \
      "$image"
  containers+=("$container_name")
  docker wait "$container_name"
  info "Container $container_name stopped."
  if docker logs "$container_name" | grep 'INFO: EXECUTION SUCCESS'; then
    scanner_finished_successfuly=yes
  fi

  [[ "$scanner_finished_successfuly" == yes ]]
}

launch_sonarqube() {
  info "Starting SonarQube in container $sonarqube_container_name in detached mode..."
  docker run --network="$network" --name="$sonarqube_container_name" -d -p "$port:9000" sonarqube:enterprise
  containers+=("$sonarqube_container_name")
  if wait_for_sonarqube ; then
    info "SonarQube has been started."
  else
    fatal "Failed to launch SonarQube"
  fi
}

clean_up() {
  info "Stopping and removing containers: [${containers[*]}]"
  docker stop "${containers[@]}"
  docker rm "${containers[@]}"
  info "Containers [${containers[*]}] have been stopped and removed."
  rm -Rf "$scanner_cache" && info "Scanner cache $scanner_cache deleted"
}

require curl docker

for arg; do
  if [[ $arg == "-h" ]] || [[ $arg == "--help" ]]; then
    print_usage
    exit
  fi
done

if [[ $# == 0 ]]; then
  fatal "at least one image as parameter is required"
fi

images=("$@")
results=()

create_network
launch_sonarqube
create_scanner_cache

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
  info "${images[i]} => ${results[i]}"
  if [[ ${results[i]} != success ]]; then
    ((failures++)) || :
  fi
done

[[ $failures == 0 ]]
