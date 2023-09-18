FROM eclipse-temurin:17-jre

LABEL org.opencontainers.image.url=https://github.com/SonarSource/sonar-scanner-cli-docker

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG SONAR_SCANNER_VERSION=5.0.1.3006
ARG NODE_MAJOR=18
ENV JAVA_HOME=/opt/java/openjdk \
    HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_USER_HOME=${SONAR_SCANNER_HOME}/.sonar \
    PATH=${SONAR_SCANNER_HOME}/bin:${PATH} \
    NODE_PATH=/usr/lib/node_modules \
    SRC_PATH=/usr/src \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

WORKDIR /opt

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN groupadd --system --gid 1000 scanner-cli && \
    useradd --system --uid 1000 --gid scanner-cli scanner-cli && \
    apt-get -qqy update && \
    apt-get --no-install-recommends -qqy install ca-certificates curl gnupg  && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get -qqy update && \
    apt-get --no-install-recommends -qqy install git unzip wget bash fonts-dejavu python3 python3-pip shellcheck nodejs build-essential && \
    curl -fsSL -o /opt/sonar-scanner-cli.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip && \
    curl -fsSL -o /opt/sonar-scanner-cli.zip.asc https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip.asc && \
    for server in $(shuf -e hkps://keys.openpgp.org \
                            hkps://keyserver.ubuntu.com) ; do \
        gpg --batch --keyserver "${server}" --recv-keys 679F1EE92B19609DE816FDE81DB198F93525EC1A && break || : ; \
    done && \
    gpg --verify /opt/sonar-scanner-cli.zip.asc /opt/sonar-scanner-cli.zip && \
    unzip sonar-scanner-cli.zip && \
    rm sonar-scanner-cli.zip sonar-scanner-cli.zip.asc && \
    mv sonar-scanner-${SONAR_SCANNER_VERSION} ${SONAR_SCANNER_HOME} && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir pylint && \
    mkdir -p "${SRC_PATH}" "${SONAR_USER_HOME}" "${SONAR_USER_HOME}/cache" && \
    chmod -R 555 "${SONAR_SCANNER_HOME}" "${SRC_PATH}" && \
    chmod -R 777 "${SRC_PATH}" "${SONAR_USER_HOME}" && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=scanner-cli:scanner-cli bin /usr/bin/

USER scanner-cli

VOLUME [ "/tmp/cacerts" ]

WORKDIR ${SRC_PATH}

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["sonar-scanner"]
