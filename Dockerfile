FROM curlimages/curl:7.83.1 as downloader
ENV OC_VERSION 4.10.17
ENV OC_SHA256 92c98fce2b3658db0584849b818cf9ca3509ff645da94e87527a6841e591e4af
ENV OC_URL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux-${OC_VERSION}.tar.gz"
ENV YQ_VERSION 4.16.2
ENV YQ_SHA512 b6705fe25f781f618e34f28ba57b2fbe14e836193fbc17820a9cdfa37245267ed98a21005f37d7c158db5622c2c5f552b96c2966b5802ab1a5c13cc968f54e21
ENV USERNAME=osyb
ENV BASE=/opt/${USERNAME}
WORKDIR /tmp
COPY osyb .
USER root
RUN echo "Downloading ${OC_URL}" && \
    curl -sL "${OC_URL}" > oc.tar.gz && \
    echo "${OC_SHA256}  oc.tar.gz" | sha256sum -c && \
    tar zxvf /tmp/oc.tar.gz && \
    curl -sL https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 > yq && \
    sha512sum /tmp/yq && \
    echo "${YQ_SHA512}  yq" | sha512sum -c && \
    curl -sL https://raw.githubusercontent.com/trivento/scripts/main/openshift/openshift-docker-user-entrypoint.sh > entrypoint.sh && \
    curl -sL https://raw.githubusercontent.com/trivento/scripts/main/openshift/openshift-docker-user.sh > user.sh && \
    chmod +x oc yq user.sh && \
    ./user.sh

# build from source because apk git-secret repo is dead
# https://github.com/sobolevn/git-secret/issues/878#issuecomment-1166263653
FROM alpine:3.16.0 as git-secret-builder
RUN apk add --no-cache --update \
    # fpm deps:
    ruby \
    ruby-dev \
    ruby-etc \
    gcc \
    libffi-dev \
    make \
    libc-dev \
    rpm \
    tar \
    # Direct dependencies:
    bash \
    gawk \
    git \
    gnupg \
    # Assumed to be present:
    curl \
    # envsubst for `nfpm`:
    gettext && \
    git clone -b v0.5.0 https://github.com/sobolevn/git-secret.git git-secret && \
    cd git-secret && \
    make build && \
    make install && \
    /usr/bin/git-secret --version

FROM alpine:3.16.0
ENV BIN=/usr/local/bin/
ENV USERNAME=osyb
ENV BASE=/opt/${USERNAME}
ENV BASE_BIN=${BASE}/bin
ENV PATH=${BASE_BIN}:${PATH}
COPY --from=downloader /tmp/oc /tmp/yq $BIN
COPY --from=downloader /etc/passwd /etc/passwd
COPY --from=downloader /opt/ /opt/
COPY --from=git-secret-builder /usr/bin/git-secret /usr/local/bin/git-secret
RUN apk add --update --no-cache \
    curl && \
    ls -ltr /opt | grep $USERNAME | grep "\-\-\-rwx\-\-\-" && \
    ls /opt | wc -l | grep "^1$" && \
    apk add --update --no-cache \
    # libc6-compat is required by oc in order to start:
    # * sh: oc: not found
    libc6-compat \
    bash \
    findutils \
    git \
    openssh \
    py-pip \
    gawk \
    gpg && \
    git-secret --version && \
    pip3 install --upgrade --no-cache-dir \
    pip \
    yamllint==1.20.0
USER $USERNAME
WORKDIR $BASE
ENTRYPOINT ["entrypoint.sh"]
CMD ["osyb"]
