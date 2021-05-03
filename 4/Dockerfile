FROM adoptopenjdk/openjdk11:alpine-jre

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG SONAR_SCANNER_VERSION
ARG UID=1000
ARG GID=1000
ENV JAVA_HOME=/opt/java/openjdk \
    HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_USER_HOME=${SONAR_SCANNER_HOME}/.sonar \
    PATH=/opt/java/openjdk/bin:${SONAR_SCANNER_HOME}/bin:${PATH} \
    SRC_PATH=/usr/src

WORKDIR /opt

RUN set -ex \
    && addgroup -S -g ${GID} scanner-cli \
    && adduser -S -D -u ${UID} -G scanner-cli scanner-cli \
    && apk add --no-cache --virtual build-dependencies wget unzip gnupg \
    && apk add --no-cache git python3 py-pip bash shellcheck 'nodejs>10' 'npm>10' \
    && wget -U "scannercli" -q -O /opt/sonar-scanner-cli.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip \
    && wget -U "scannercli" -q -O /opt/sonar-scanner-cli.zip.asc https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip.asc \
    && wget -U "scannercli" -q -O /opt/sonarsource-public.key https://binaries.sonarsource.com/sonarsource-public.key \
    && gpg --import /opt/sonarsource-public.key \
    && gpg --verify /opt/sonar-scanner-cli.zip.asc /opt/sonar-scanner-cli.zip \
    && unzip sonar-scanner-cli.zip \
    && rm sonar-scanner-cli.zip sonar-scanner-cli.zip.asc \
    && mv sonar-scanner-${SONAR_SCANNER_VERSION} ${SONAR_SCANNER_HOME} \
    && npm install -g typescript@3.7.5 \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir pylint \
    && apk del --purge build-dependencies \
    && mkdir -p "${SRC_PATH}" "${SONAR_USER_HOME}" "${SONAR_USER_HOME}/cache"\
    && chown -R scanner-cli:scanner-cli "${SONAR_SCANNER_HOME}" "${SRC_PATH}" \
    && chmod -R 777 "${SRC_PATH}" "${SONAR_USER_HOME}"

COPY --chown=scanner-cli:scanner-cli bin /usr/bin/

WORKDIR ${SRC_PATH}

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["sonar-scanner"]
