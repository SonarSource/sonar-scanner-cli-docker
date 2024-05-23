FROM alpine:3.19

LABEL org.opencontainers.image.url=https://github.com/SonarSource/sonar-scanner-cli-docker

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG SONAR_SCANNER_VERSION=5.0.1.3006
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk \
    HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_USER_HOME=${SONAR_SCANNER_HOME}/.sonar \
    PATH=${SONAR_SCANNER_HOME}/bin:${PATH} \
    SRC_PATH=/usr/src \
    SCANNER_WORKDIR_PATH=/tmp/.scannerwork \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

WORKDIR /opt

RUN set -eux; \
    addgroup -S -g 1000 scanner-cli; \
    adduser -S -D -u 1000 -G scanner-cli scanner-cli; \
    apk add --no-cache --virtual build-dependencies wget unzip gnupg; \
    apk add --no-cache git bash shellcheck "nodejs>=18" openjdk17-jre musl-locales musl-locales-lang tar; \
    wget -U "scannercli" -q -O /opt/sonar-scanner-cli.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip; \
    wget -U "scannercli" -q -O /opt/sonar-scanner-cli.zip.asc https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip.asc; \
    for server in $(shuf -e hkps://keys.openpgp.org \
                            hkps://keyserver.ubuntu.com) ; do \
        gpg --batch --keyserver "${server}" --recv-keys 679F1EE92B19609DE816FDE81DB198F93525EC1A && break || : ; \
    done; \
    gpg --verify /opt/sonar-scanner-cli.zip.asc /opt/sonar-scanner-cli.zip; \
    unzip sonar-scanner-cli.zip; \
    rm sonar-scanner-cli.zip sonar-scanner-cli.zip.asc; \
    mv sonar-scanner-${SONAR_SCANNER_VERSION} ${SONAR_SCANNER_HOME}; \
    apk del --purge build-dependencies; \
    mkdir -p "${SRC_PATH}" "${SONAR_USER_HOME}" "${SONAR_USER_HOME}/cache" "${SCANNER_WORKDIR_PATH}"; \
    chown -R scanner-cli:scanner-cli "${SONAR_SCANNER_HOME}" "${SRC_PATH}" "${SCANNER_WORKDIR_PATH}"; \
    chmod -R 555 "${SONAR_SCANNER_HOME}"; \
    chmod -R 754 "${SRC_PATH}" "${SONAR_USER_HOME}" "${SCANNER_WORKDIR_PATH}";

COPY --chown=scanner-cli:scanner-cli bin /usr/bin/

USER scanner-cli

VOLUME [ "/tmp/cacerts" ]

WORKDIR ${SRC_PATH}

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["sonar-scanner"]