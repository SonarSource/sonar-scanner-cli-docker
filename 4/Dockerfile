FROM debian:stretch-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git wget unzip xz-utils pylint \
    && rm -rf /var/lib/apt/lists/*

ARG SONAR_SCANNER_HOME=/usr/local/sonar-scanner
ARG NODEJS_HOME=/usr/local/nodejs

ENV SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_SCANNER_VERSION=4.1.0.1829 \
    NODEJS_HOME=${NODEJS_HOME} \
    NODEJS_VERSION=v8.12.0 \
    PATH=${SONAR_SCANNER_HOME}/bin:${NODEJS_HOME}/bin:${PATH} \
    NODE_PATH=${NODEJS_HOME}/lib/node_modules

WORKDIR /usr/local

RUN groupadd -r scanner-cli \
    && useradd --no-log-init -r -g scanner-cli scanner-cli

RUN wget -U "scannercli" -q -O /usr/local/sonar-scanner-cli.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip \
    && unzip sonar-scanner-cli.zip \
    && rm sonar-scanner-cli.zip \
    && mv sonar-scanner-${SONAR_SCANNER_VERSION}-linux ${SONAR_SCANNER_HOME} \
    && chown -R scanner-cli:scanner-cli ${SONAR_SCANNER_HOME} \
    && wget -U "nodejs" -q -O nodejs.tar.xz https://nodejs.org/dist/${NODEJS_VERSION}/node-${NODEJS_VERSION}-linux-x64.tar.xz \
    && tar Jxf nodejs.tar.xz \
    && rm nodejs.tar.xz \
    && mv node-${NODEJS_VERSION}-linux-x64 ${NODEJS_HOME} \
    && npm install -g typescript

COPY bin /usr/bin/

USER scanner-cli
WORKDIR /usr/src

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
