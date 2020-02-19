FROM alpine:3.11

ARG SONAR_SCANNER_VERSION=4.2.0.1873
ARG SONAR_SOURCE_KEY=F1182E81C792928921DBCAB4CFCA4A29D26468DE
ARG SONAR_SCANNER_FILE=sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip
ARG JDK_VERSION=11

ENV SONAR_SCANNER_VERSION=${SONAR_SCANNER_VERSION}
ENV SONAR_SCANNER_FILE=${SONAR_SCANNER_FILE}
ENV SONAR_SOURCE_KEY=${SONAR_SOURCE_KEY}
ENV JDK_VERSION=${JDK_VERSION}
ENV SONAR_SCANNER_USER=scanner-cli
ENV SONAR_SCANNER_ID=1001
ENV SONAR_SCANNER_HOME=/opt/sonar-scanner
ENV PATH=$PATH:${SONAR_SCANNER_HOME}/bin

WORKDIR /opt

ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${SONAR_SCANNER_FILE} /opt/sonar-scanner-cli.zip
ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${SONAR_SCANNER_FILE}.asc /opt/sonar-scanner-cli.zip.asc

RUN apk update \
    && apk upgrade \
    && apk --no-cache --update add bash p7zip ca-certificates gnupg openjdk${JDK_VERSION}-jre-headless nodejs npm \
    && addgroup -g ${SONAR_SCANNER_ID} ${SONAR_SCANNER_USER} \
    && adduser -D -u ${SONAR_SCANNER_ID} -g "" -G ${SONAR_SCANNER_USER} ${SONAR_SCANNER_USER} \
    && wget "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${SONAR_SOURCE_KEY}" -O ${SONAR_SOURCE_KEY}.key \
    && gpg --import ${SONAR_SOURCE_KEY}.key \
    && gpg --no-default-keyring --verify sonar-scanner-cli.zip.asc || exit 1 \
    && 7z x sonar-scanner-cli.zip \
    && mv sonar-scanner-${SONAR_SCANNER_VERSION}-linux ${SONAR_SCANNER_HOME} \
    && chown ${SONAR_SCANNER_USER}:${SONAR_SCANNER_USER} -R ${SONAR_SCANNER_HOME} \
    && rm -rf /opt/sonar-scanner/jre \
    && mkdir -p /usr/src /opt/sonar-scanner/jre/bin \
    && ln -s /usr/bin/java /opt/sonar-scanner/jre/bin/java \
    && chown ${SONAR_SCANNER_USER}:${SONAR_SCANNER_USER} -R /usr/src \
    && npm cache clean --force\
    && apk del p7zip ca-certificates gnupg npm wget \
    && rm -rf "./*.zip" /var/cache/apk/

WORKDIR /usr/src

USER ${SONAR_SCANNER_USER}

ENTRYPOINT ["/opt/sonar-scanner/bin/sonar-scanner"]
CMD ["-Dsonar.projectBaseDir=/usr/src"]
