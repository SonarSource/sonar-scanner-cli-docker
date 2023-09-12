setup_suite() {
    docker network create it-sonarqube

    docker run --network=it-sonarqube --name=it-sonarqube -d sonarqube:enterprise

    until docker run --network=it-sonarqube --rm curlimages/curl:8.2.1 -so - it-sonarqube:9000/api/system/status | grep '"status":"UP"' ; do
        sleep 5
    done

}

teardown_suite() {
    docker rm -f it-sonarqube
    docker network rm it-sonarqube
}