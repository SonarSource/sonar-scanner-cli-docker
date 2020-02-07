[![Build Status](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker.svg?branch=master)](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker)

# SonarScanner CLI

This is the Git repository that contains source for [SonarScanner CLI](https://github.com/SonarSource/sonar-scanner-cli)
Docker images.
Images are available on [Docker Hub](https://hub.docker.com/r/sonarsource/sonar-scanner-cli).

NB: These Docker images are not compatible with C/C++/Objective-C projects.

## Beta

This image is currently in Beta testing and is made available to gather
feedback.

## License

Copyright 2015-2019 SonarSource.

Licensed under the [GNU Lesser General Public License, Version 3.0](http://www.gnu.org/licenses/lgpl.txt)

## How to run the Docker image

### Running

```
docker run --user="$(id -u):$(id -g)" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli -Dsonar.projectKey=<KEY>  -Dsonar.sources=.  -Dsonar.host.url=http://host.docker.internal:9000  -Dsonar.login=<STRING>
```

To analysis the project in the current directory:

```
docker run --user="$(id -u):$(id -g)" -it -v "$(PWD):/usr/src" sonarsource/sonar-scanner-cli -Dsonar.projectKey=<KEY>  -Dsonar.sources=.  -Dsonar.host.url=http://host.docker.internal:9000  -Dsonar.login=<STRING>
```

#### With SonarQube running in Docker

Create a network and boot SonarQube:

```
docker network create "scanner-sq-network"
docker run --network="scanner-sq-network" --name="sq" -d sonarqube
```

And run the scanner:

```
docker run --user="$(id -u):$(id -g)" -it -v "$(PWD):/usr/src" --network="scanner-sq-network" sonarsource/sonar-scanner-cli -Dsonar.projectKey=<KEY>  -Dsonar.sources=.  -Dsonar.host.url=http://host.docker.internal:9000  -Dsonar.login=<STRING>
```

## Write permissions

The scanner writes to the analysed project's directory,
creating directories `${SONAR_PROJECT_BASE_DIR}/.scannerwork` and
`${SONAR_PROJECT_BASE_DIR}/.sonar`.

By default scanner writes with user id `1001` and group id `1001`. The `--user`
option (see sample commands above) is used on Linux to have the scanner write
with the same user and group as the caller to the `docker run` command.

### Project mounting point

By default, the scanner analyses the project in directory `/usr/src`.

### Caching and scanner user home directory

When running the scanner with this image, the `.sonar` directory is created in
the project's directory. This implies caching is not happening accross analysis
of multiple projects.

## Suported variables

### Docker arguments and environment variables

```
ARG JDK_VERSION=11
ARG SONAR_SCANNER_FILE=sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip
ARG SONAR_SCANNER_VERSION=4.2.0.1873
ARG SONAR_SOURCE_KEY=F1182E81C792928921DBCAB4CFCA4A29D26468DE

ENV JDK_VERSION=${JDK_VERSION}
ENV PATH=$PATH:${SONAR_SCANNER_HOME}/bin
ENV SONAR_SCANNER_FILE=${SONAR_SCANNER_FILE}
ENV SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV SONAR_SCANNER_ID=1001
ENV SONAR_SCANNER_USER=scanner-cli
ENV SONAR_SCANNER_VERSION=${SONAR_SCANNER_VERSION}
ENV SONAR_SOURCE_KEY=${SONAR_SOURCE_KEY}
```

## Developer documentation

### Building

Each major version of the scanner gets its own image in a specific directory.

```
git clone https://github.com/SonarSource/sonar-scanner-cli-docker
cd sonar-scanner-cli-docker/<VERSION>/
docker build --no-cache --tag sonarsource/sonar-scanner-cli -f Dockerfile .
```

### How to publish the Docker image

The [Travis](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker) job
building this repository is publishing every successful build of the master
branch to the [SonarSource organization](https://hub.docker.com/r/sonarsource/sonar-scanner-cli)
on Docker Hub.

Credentials to Docker Hub are provided as Travis environment variables to the
build script (coded directly into [`.travis.yml`](.travis.yml)).

The latest version of the scanner is published under the alias `latest`. Each
scanner version is published under at least one version alias
(`X`, `X.0`, `X.Y`, ...).

### Automatic tests

The [Travis](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker) job
builds the docker image for sonar-scanner 4 and tests it against the demo
project `sonarqube-scanner` from SonarSource services maintained repository
[`sonar-scanning-examples`](https://github.com/SonarSource/sonar-scanning-examples).

For details, see [run-tests.sh](run-tests.sh).

This test is run on any branch. Test is successful if scanner ran and exited
with code 0.

To test another version of the scanner, update the script part of [`.travis.yml`](.travis.yml).

[run-tests.sh](run-tests.sh) can also be used on a developer machine with Docker
installed.
