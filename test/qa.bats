load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup_file() {
    export DIR
    # shellcheck disable=SC2154  # BATS_TEST_FILENAME is set by bats
    DIR="$( cd "$( dirname "${BATS_TEST_FILENAME}" )" >/dev/null 2>&1 && pwd )"

    echo "# Create Docker Network for Integration Tests" >&3
    docker network create it-sonarqube

    echo "# Start SonarQube Enterprise for Integration Tests" >&3
    docker run --network=it-sonarqube --name=it-sonarqube -d sonarqube:enterprise

    echo "# Wait for SonarQube to be up and running" >&3
    # shellcheck disable=2312  # The return value is irrelevant
    until docker run --network=it-sonarqube --rm curlimages/curl:8.4.0 -so - it-sonarqube:9000/api/system/status | grep '"status":"UP"' ; do
        sleep 5
    done
}

teardown_file() {
    docker rm -f it-sonarqube
    docker network rm it-sonarqube
}

@test "scan test project" {
    # shellcheck disable=SC2154  # DIR is set by setup
    local REPO_DIR="${DIR}/../target_repository"

    local PROJECT_SCAN_DIR="${REPO_DIR}/sonar-scanner"
    scanner_props_location="${PROJECT_SCAN_DIR}/sonar-project.properties"

    cat <<EOF > "${scanner_props_location}"
    sonar.projectKey=it-sonarqube-test
    sonar.login=admin
    sonar.password=admin
EOF

    # shellcheck disable=SC2154  # TEST_IMAGE is provided as an environment variable
    run docker run --network=it-sonarqube --rm \
        -v "${PROJECT_SCAN_DIR}:/usr/src" \
        --env SONAR_HOST_URL="http://it-sonarqube:9000" \
        "${TEST_IMAGE}"

    assert_output --partial 'INFO  EXECUTION SUCCESS'
}

@test "scan test project with cache mapped to host folder" {
    local tmpDir=""
    tmpDir="$(mktemp -d)"
    SONAR_SCANNER_CACHE="${tmpDir}/.sonar"
    mkdir -p "${SONAR_SCANNER_CACHE}"
    # let the scanner-cli user write to the cache folder
    chmod o+w "${SONAR_SCANNER_CACHE}"

    # shellcheck disable=SC2154  # DIR is set by setup_suite
    local REPO_DIR="${DIR}/../target_repository"

    local PROJECT_SCAN_DIR="${REPO_DIR}/sonar-scanner"
    scanner_props_location="${PROJECT_SCAN_DIR}/sonar-project.properties"

    cat <<EOF > "${scanner_props_location}"
    sonar.projectKey=it-sonarqube-test
    sonar.login=admin
    sonar.password=admin
EOF

    # shellcheck disable=SC2154  # TEST_IMAGE is provided as an environment variable
    run docker run --network=it-sonarqube --rm \
        -v "${PROJECT_SCAN_DIR}:/usr/src" \
        -v "${SONAR_SCANNER_CACHE}:/usr/.sonar" \
        --env SONAR_HOST_URL="http://it-sonarqube:9000" \
        --env SONAR_USER_HOME="/usr/.sonar" \
        "${TEST_IMAGE}"

    assert_output --partial 'INFO  EXECUTION SUCCESS'

    rm -rf "${tmpDir}"
}

@test "ensure we have nodejs installed" {
    run docker run --rm --entrypoint=node "${TEST_IMAGE}" --version
    assert_output --regexp '[0-9]+\.[0-9]+\.[0-9]+'
}

@test "ensure we can add certificates the new way" {
    # shellcheck disable=SC2154  # DIR is set by setup_suite
    local REPO_DIR="${DIR}/../target_repository"

    local PROJECT_SCAN_DIR="${REPO_DIR}/sonar-scanner"
    scanner_props_location="${PROJECT_SCAN_DIR}/sonar-project.properties"

    cat <<EOF > "${scanner_props_location}"
    sonar.projectKey=it-sonarqube-test
    sonar.login=admin
    sonar.password=admin
EOF

    # shellcheck disable=SC2154  # TEST_IMAGE is provided as an environment variable
    run docker run --network=it-sonarqube --rm \
        -v "${PROJECT_SCAN_DIR}:/usr/src" \
        -v ${DIR}/ssl:/opt/sonar-scanner/.sonar/ssl \
        --env SONAR_HOST_URL="http://it-sonarqube:9000" \
        "${TEST_IMAGE}"

    assert_output --partial 'INFO  EXECUTION SUCCESS'
}

@test "ensure we can add certificates the old way" {
    # shellcheck disable=SC2154  # DIR is set by setup_suite
    local REPO_DIR="${DIR}/../target_repository"

    local PROJECT_SCAN_DIR="${REPO_DIR}/sonar-scanner"
    scanner_props_location="${PROJECT_SCAN_DIR}/sonar-project.properties"

    cat <<EOF > "${scanner_props_location}"
    sonar.projectKey=it-sonarqube-test
    sonar.login=admin
    sonar.password=admin
EOF

    # shellcheck disable=SC2154  # TEST_IMAGE is provided as an environment variable
    run docker run --network=it-sonarqube --rm \
        -v "${PROJECT_SCAN_DIR}:/usr/src" \
        -v ${DIR}/cacerts:/tmp/cacerts \
        --env SONAR_HOST_URL="http://it-sonarqube:9000" \
        "${TEST_IMAGE}"

    assert_output --partial 'Importing certificates from /tmp/cacerts is deprecated'
    assert_output --partial 'INFO  EXECUTION SUCCESS'
}
