[![Build Status](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker.svg?branch=master)](https://travis-ci.org/SonarSource/sonar-scanner-cli-docker)

# SonarScanner CLI

This is the Git repository that contains source for [SonarScanner CLI](https://github.com/SonarSource/sonar-scanner-cli) Docker images.
Images are available on [Docker Hub](https://hub.docker.com/r/sonarsource/sonar-scanner-cli).

NB: These Docker images are not compatible with C/C++/Objective-C projects.

## Beta

This image is currently in Beta testing and is made available to gather feedback.

## License

Copyright 2015-2019 SonarSource.

Licensed under the [GNU Lesser General Public License, Version 3.0](http://www.gnu.org/licenses/lgpl.txt)

# How to run the Docker image

## On Linux

## Building

```
git clone https://github.com/SonarSource/sonar-scanner-cli-docker
cd sonar-scanner-cli-docker/<VERSION>/
docker build --no-cache --tag sonarsource/sonar-scanner-cli -f Dockerfile .
```

### Running

```
docker run --user="$(id -u):$(id -g)" -it -v "/path/to/project:/usr/src" sonarsource/sonar-scanner-cli -Dsonar.projectKey=<KEY>  -Dsonar.sources=.  -Dsonar.host.url=http://host.docker.internal:9000  -Dsonar.login=<STRING>
```

To analysis the project in the current directory:

```
docker run --user="$(id -u):$(id -g)" -it -v "$(PWD):/usr/src" sonarsource/sonar-scanner-cli -Dsonar.projectKey=<KEY>  -Dsonar.sources=.  -Dsonar.host.url=http://host.docker.internal:9000  -Dsonar.login=<STRING>
```

### Write permissions

The scanner writes to the analysed project's directory, in directory `${SONAR_PROJECT_BASE_DIR}/.scannerwork`.

By default scanner writes with user id `1001` and group id `1001`. The `--user` option (see sample commands above) is used on Linux to have the scanner write with the same user and group as the caller to the `docker run` command.

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

### Project mounting point

By default, the scanner analyses the project in directory `/usr/src`.

### Scanner user home

The scanner downloads data from the SonarQube server it connects to. Retrieving this data can take time and certainly takes bandwidth. For efficiency, the scanner caches this data in the user home (directory named `.sonar`).

When running the scanner with this image, this `.sonar` directory is created in the project's directory. This implies caching is not happening accross analysis of multiple projects.

Caching is actually shared between projects when running the scanner natively as the `.sonar` is created in the home directory of the current user.

# Developer documentation

Developer documentation is available in [DEVELOPER.md](DEVELOPER.md).
