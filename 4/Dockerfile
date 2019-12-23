ARG NODEJS_VERSION=10.18.0
FROM node:${NODEJS_VERSION}-stretch-slim

ARG SONAR_SCANNER_VERSION=4.2.0.1873
ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_SCANNER_VERSION=${SONAR_SCANNER_VERSION} \
    PATH=${SONAR_SCANNER_HOME}/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git unzip pylint \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g typescript@3.7.4

ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip /opt/sonar-scanner-cli.zip

WORKDIR /opt
RUN unzip sonar-scanner-cli.zip \
    && rm sonar-scanner-cli.zip \
    && mv sonar-scanner-${SONAR_SCANNER_VERSION}-linux ${SONAR_SCANNER_HOME}

COPY bin /usr/bin/

WORKDIR /usr/src

USER node

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
