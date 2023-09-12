@test "scan test project" {
    local tmpDir=""
    tmpDir="$(mktemp -d)"
    SONAR_SCANNER_CACHE="${tmpDir}/.sonar"
    mkdir -p "${SONAR_SCANNER_CACHE}"

    scanner_tmp_dir=$(mktemp -d)
    mkdir -p "${scanner_tmp_dir}/target_repository/sonarqube-scanner"
    scanner_props_location="${scanner_tmp_dir}/target_repository/sonarqube-scanner/sonar-project.properties"

    cat <<EOF > "${scanner_props_location}"
    sonar.projectKey=it-sonarqube-test
    sonar.login=admin
    sonar.password=admin
EOF

    docker run --network=it-sonarqube --rm \
        --user="$(id -u):$(id -g)" \
        -v "${scanner_tmp_dir}/target_repository/sonarqube-scanner:/usr/src" \
        -v "${SONAR_SCANNER_CACHE}:/usr/.sonar" \
        --env SONAR_HOST_URL="http://it-sonarqube:9000" \
        --env SONAR_USER_HOME="/usr/.sonar" \
        "${TEST_IMAGE}"
}

@test "ensure we have nodejs 18 installed" {
    run docker run --rm --entrypoint=node "${TEST_IMAGE}" --version
    [[ "${output}" =~ v18\.[0-9]+\.[0-9]+ ]]
}

@test "ensure we are using Java 17" {
    run docker run --rm --entrypoint=java "${TEST_IMAGE}" --version
    [[ "${output}" =~ 17\.[0-9]+\.[0-9]+ ]]
}
