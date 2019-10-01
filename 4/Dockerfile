FROM debian:stretch-slim

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG NODEJS_HOME=/opt/nodejs
ARG UID=1000
ARG GID=1000
ENV SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_SCANNER_VERSION=4.2.0.1873 \
    NODEJS_HOME=${NODEJS_HOME} \
    NODEJS_VERSION=v10.16.3 \
    PATH=${SONAR_SCANNER_HOME}/bin:${NODEJS_HOME}/bin:${PATH} \
    NODE_PATH=${NODEJS_HOME}/lib/node_modules

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git wget unzip xz-utils pylint \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${GID} scanner-cli \
    && useradd --uid ${UID} --gid scanner-cli --shell /bin/bash --create-home scanner-cli

WORKDIR /opt
RUN wget -U "scannercli" -q -O /opt/sonar-scanner-cli.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip \
    && unzip sonar-scanner-cli.zip \
    && rm sonar-scanner-cli.zip \
    && mv sonar-scanner-${SONAR_SCANNER_VERSION}-linux ${SONAR_SCANNER_HOME} \
    && wget -U "nodejs" -q -O nodejs.tar.xz https://nodejs.org/dist/${NODEJS_VERSION}/node-${NODEJS_VERSION}-linux-x64.tar.xz \
    && tar Jxf nodejs.tar.xz \
    && rm nodejs.tar.xz \
    && mv node-${NODEJS_VERSION}-linux-x64 ${NODEJS_HOME} \
    && npm install -g typescript@3.6.3

COPY --chown=scanner-cli:scanner-cli bin /usr/bin/

WORKDIR /usr/src

USER scanner-cli

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
