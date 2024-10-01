FROM alpine:3.19 AS builder

LABEL org.opencontainers.image.url=https://github.com/SonarSource/sonar-scanner-cli-docker

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG SONAR_SCANNER_VERSION=6.2.0.4584
ENV HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SCANNER_BINARIES=https://binaries.sonarsource.com/Distribution/sonar-scanner-cli
ENV SCANNER_ZIP_URL="${SCANNER_BINARIES}/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip"

WORKDIR /opt

ADD ${SCANNER_ZIP_URL} /opt/sonar-scanner-cli.zip
ADD ${SCANNER_ZIP_URL}.asc /opt/sonar-scanner-cli.zip.asc

RUN set -eux; \
    apk add --no-cache --virtual build-dependencies gnupg unzip wget; \
    for server in $(shuf -e hkps://keys.openpgp.org \
                            hkps://keyserver.ubuntu.com) ; do \
        gpg --batch --keyserver "${server}" --recv-keys 679F1EE92B19609DE816FDE81DB198F93525EC1A && break || : ; \
    done; \
    gpg --verify /opt/sonar-scanner-cli.zip.asc /opt/sonar-scanner-cli.zip; \
    unzip sonar-scanner-cli.zip; \
    rm sonar-scanner-cli.zip sonar-scanner-cli.zip.asc; \
    mv sonar-scanner-${SONAR_SCANNER_VERSION} ${SONAR_SCANNER_HOME}; \
    apk del --purge build-dependencies;


FROM amazoncorretto:17-al2023 AS scanner-cli-base

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_USER_HOME=${SONAR_SCANNER_HOME}/.sonar \
    PATH=${SONAR_SCANNER_HOME}/bin:${PATH} \
    SRC_PATH=/usr/src \
    SCANNER_WORKDIR_PATH=/tmp/.scannerwork \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Copy Scanner installation from builder image
COPY --from=builder /opt/sonar-scanner /opt/sonar-scanner

RUN \
    dnf install -y git \
    && dnf install -y tar \
    && dnf install -y nodejs \
    && dnf clean all \
    && set -eux \
    && groupadd --system --gid 1000 scanner-cli \
    && useradd --system --uid 1000 --gid scanner-cli scanner-cli \
    && chown -R scanner-cli:scanner-cli "${SONAR_SCANNER_HOME}" "${SRC_PATH}" \
    && mkdir -p "${SRC_PATH}" "${SONAR_USER_HOME}" "${SONAR_USER_HOME}/cache" "${SCANNER_WORKDIR_PATH}" \
    && chown -R scanner-cli:scanner-cli "${SONAR_SCANNER_HOME}" "${SRC_PATH}" "${SCANNER_WORKDIR_PATH}" \
    && chmod -R 555 "${SONAR_SCANNER_HOME}" \
    && chmod -R 754 "${SRC_PATH}" "${SONAR_USER_HOME}" "${SCANNER_WORKDIR_PATH}" \
    # Security updates
    && dnf upgrade -y --releasever=latest --security

COPY --chown=scanner-cli:scanner-cli bin /usr/bin/

USER scanner-cli

WORKDIR ${SRC_PATH}

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["sonar-scanner"]
