FROM alpine:3.11
ENV JAVA_VERSION="jdk-11.0.6+10" \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

#
# glibc setup
#
RUN set -eux; \
    apk add --no-cache --virtual .build-deps curl binutils; \
    GLIBC_VER="2.31-r0"; \
    ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download"; \
    GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-9.1.0-2-x86_64.pkg.tar.xz"; \
    GCC_LIBS_SHA256="91dba90f3c20d32fcf7f1dbe91523653018aa0b8d2230b00f822f6722804cf08"; \
    ZLIB_URL="https://archive.archlinux.org/packages/z/zlib/zlib-1%3A1.2.11-3-x86_64.pkg.tar.xz"; \
    ZLIB_SHA256="17aede0b9f8baa789c5aa3f358fbf8c68a5f1228c5e6cba1a5dd34102ef4d4e5"; \
    curl -LfsS https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub; \
    SGERRAND_RSA_SHA256="823b54589c93b02497f1ba4dc622eaef9c813e6b0f0ebbb2f771e32adf9f4ef2"; \
    echo "${SGERRAND_RSA_SHA256} */etc/apk/keys/sgerrand.rsa.pub" | sha256sum -c -; \
    curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/glibc-${GLIBC_VER}.apk; \
    apk add --no-cache /tmp/glibc-${GLIBC_VER}.apk; \
    curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk > /tmp/glibc-bin-${GLIBC_VER}.apk; \
    apk add --no-cache /tmp/glibc-bin-${GLIBC_VER}.apk; \
    curl -LfsS ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-i18n-${GLIBC_VER}.apk > /tmp/glibc-i18n-${GLIBC_VER}.apk; \
    apk add --no-cache /tmp/glibc-i18n-${GLIBC_VER}.apk; \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true; \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh; \
    curl -LfsS ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.xz; \
    echo "${GCC_LIBS_SHA256} */tmp/gcc-libs.tar.xz" | sha256sum -c -; \
    mkdir /tmp/gcc; \
    tar -xf /tmp/gcc-libs.tar.xz -C /tmp/gcc; \
    mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib; \
    strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so*; \
    curl -LfsS ${ZLIB_URL} -o /tmp/libz.tar.xz; \
    echo "${ZLIB_SHA256} */tmp/libz.tar.xz" | sha256sum -c -; \
    mkdir /tmp/libz; \
    tar -xf /tmp/libz.tar.xz -C /tmp/libz; \
    mv /tmp/libz/usr/lib/libz.so* /usr/glibc-compat/lib; \
    apk del --purge .build-deps glibc-i18n; \
    rm -rf /tmp/*.apk /tmp/gcc /tmp/gcc-libs.tar.xz /tmp/libz /tmp/libz.tar.xz /var/cache/apk/*;

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner
ARG NODEJS_HOME=/opt/nodejs
ARG UID=1000
ARG GID=1000
ENV HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    SONAR_SCANNER_HOME=${SONAR_SCANNER_HOME} \
    SONAR_USER_HOME=${SONAR_SCANNER_HOME}/.sonar \
    SONAR_SCANNER_VERSION=4.3.0.2102 \
    NODEJS_HOME=${NODEJS_HOME} \
    NODEJS_VERSION=v10.19.0 \
    PATH=${SONAR_SCANNER_HOME}/bin:${NODEJS_HOME}/bin:${PATH} \
    NODE_PATH=${NODEJS_HOME}/lib/node_modules \
    SRC_PATH=/usr/src

RUN set -ex \
    && addgroup -S -g ${GID} scanner-cli \
    && adduser -S -D -u ${UID} -G scanner-cli scanner-cli \
    && apk add --no-cache --virtual build-dependencies wget unzip \
    && apk add --no-cache git python3 bash shellcheck \
    && wget -U "scannercli" -q -O /opt/sonar-scanner-cli.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip \
    && cd /opt \
    && unzip sonar-scanner-cli.zip \
    && rm sonar-scanner-cli.zip \
    && mv sonar-scanner-${SONAR_SCANNER_VERSION}-linux ${SONAR_SCANNER_HOME} \
    && wget -U "nodejs" -q -O nodejs.tar.xz https://nodejs.org/dist/${NODEJS_VERSION}/node-${NODEJS_VERSION}-linux-x64.tar.xz \
    && tar Jxf nodejs.tar.xz \
    && rm nodejs.tar.xz \
    && mv node-${NODEJS_VERSION}-linux-x64 ${NODEJS_HOME} \
    && npm install -g typescript@3.6.3 \
    && apk del --purge build-dependencies \
    && mkdir -p "${SRC_PATH}" "${SONAR_USER_HOME}" "${SONAR_USER_HOME}/cache"\
    && chown -R scanner-cli:scanner-cli "${SONAR_SCANNER_HOME}" "${SRC_PATH}" \
    && chmod -R 777 "${SRC_PATH}" "${SONAR_USER_HOME}"

COPY --chown=scanner-cli:scanner-cli bin /usr/bin/

WORKDIR ${SRC_PATH}

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["sonar-scanner"]
