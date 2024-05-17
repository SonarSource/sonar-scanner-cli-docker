setup_suite() {
  # shellcheck disable=SC2154  # BATS_TEST_FILENAME is set by bats
  DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )" >/dev/null 2>&1 && pwd )"

  docker network create it-sonarqube

  docker run --network=it-sonarqube --name=it-sonarqube -d sonarqube:enterprise

  # shellcheck disable=2312  # The return value is irrelevant
  until docker run --network=it-sonarqube --rm curlimages/curl:8.4.0 -so - it-sonarqube:9000/api/system/status | grep '"status":"UP"' ; do
      sleep 5
  done
}

teardown_suite() {
  docker rm -f it-sonarqube
  docker network rm it-sonarqube
}
