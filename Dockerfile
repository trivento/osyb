FROM curlimages/curl:7.80.0 as downloader
ENV OC_VERSION 4.6.32
ENV OC_SHA256 eff8fece7098937c922ff70ef2d8c2abff516bd871244708d0225f3d24c7303d
ENV OC_URL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux-${OC_VERSION}.tar.gz"
ENV GO_YQ_VERSION 2.1.5
ENV YQ_VERSION 3.4.1
ENV GO_YQ_SHA512 f1ec48a2b1334517fcb3e5dec1dc8486f4df9d78b5dca4a80f6712a85fdbc936f91b22e7f18e407086ddc095771705244fc138750319f8f31ef2ec912a19403c
ENV YQ_SHA512 52f574341975ee7c6181c50f4e694269d0fd8165915601af0f28a93b1b964c116defa0613a68cdb90b1ddec7b55094625c31da2fd264083166f7fa2edc86a47d
ENV USERNAME=osyb
ENV BASE=/opt/${USERNAME}
WORKDIR /tmp
COPY osyb .
USER root
RUN echo "Downloading ${OC_URL}" && \
    curl -sL "${OC_URL}" > oc.tar.gz && \
    echo "${OC_SHA256}  oc.tar.gz" | sha256sum -c && \
    tar zxvf /tmp/oc.tar.gz && \
    curl -sL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 > yq && \
    echo "${YQ_SHA512}  yq" | sha512sum -c && \
    curl -sL https://raw.githubusercontent.com/trivento/scripts/main/openshift/openshift-docker-user-entrypoint.sh > entrypoint.sh && \
    curl -sL https://raw.githubusercontent.com/trivento/scripts/main/openshift/openshift-docker-user.sh > user.sh && \
    chmod +x oc yq user.sh && \
    ./user.sh

FROM alpine:3.14.3
ENV BIN=/usr/local/bin/
ENV USERNAME=osyb
ENV BASE=/opt/${USERNAME}
ENV BASE_BIN=${BASE}/bin
ENV PATH=${BASE_BIN}:${PATH}
COPY --from=downloader /tmp/oc /tmp/yq $BIN
COPY --from=downloader /etc/passwd /etc/passwd
COPY --from=downloader /opt/ /opt/
RUN apk add --update --no-cache \
    curl && \
    ls -ltr /opt | grep $USERNAME | grep "\-\-\-rwx\-\-\-" && \
    ls /opt | wc -l | grep "^1$" && \
    # https://git-secret.io/installation
    sh -c "echo 'https://gitsecret.jfrog.io/artifactory/git-secret-apk/all/main'" >> /etc/apk/repositories && \
    curl 'https://gitsecret.jfrog.io/artifactory/api/security/keypair/public/repositories/git-secret-apk' > /etc/apk/keys/git-secret-apk.rsa.pub && \
    apk add --update --no-cache \
    # libc6-compat is required by oc in order to start:
    # * sh: oc: not found
    libc6-compat \
    bash \
    findutils \
    git \
    openssh \
    py-pip \
    git-secret && \
    git-secret --version && \
    pip3 install --upgrade --no-cache-dir \
    pip \
    yamllint==1.20.0
USER $USERNAME
WORKDIR $BASE
ENTRYPOINT ["entrypoint.sh"]
CMD ["osyb"]
