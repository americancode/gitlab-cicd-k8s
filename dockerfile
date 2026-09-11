FROM alpine:3.24.1

# Install prerequisites
RUN apk upgrade --no-cache && \
    apk add --no-cache bash curl git ca-certificates yq

# Create a non-root user
RUN addgroup -g 1001 alpine && \
    adduser -u 1001 -G alpine -s /bin/bash -D alpine

# Allow non-root updates to CA trust store
RUN chown -R alpine:alpine /usr/local/share/ca-certificates && \
    chown -R alpine:alpine /etc/ssl/certs && \
    chown alpine:alpine /etc/ca-certificates.conf && \
    chmod 755 /usr/local/share/ca-certificates && \
    chmod 755 /etc/ssl/certs && \
    chmod 755 /usr/sbin/update-ca-certificates

ENV KUBECTL_VERSION="1.37.0" \
    HELM_VERSION="4.3.0" \
    HELM_DIFF_VERSION="3.15.13"

# Install kubectl with checksum verification
RUN curl --fail --show-error --silent --location -o kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    curl --fail --show-error --silent --location -o kubectl.sha256 "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" && \
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    rm -f kubectl.sha256

# Install helm with checksum verification
RUN curl --fail --show-error --silent --location -o helm-v${HELM_VERSION}-linux-amd64.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    curl --fail --show-error --silent --location -o helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" && \
    sha256sum -c helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum && \
    tar -zxf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum

RUN mkdir -p /home/alpine/.cache/helm /home/alpine/.config/helm && \
    chown -R alpine:alpine /home/alpine

USER alpine

ENV HELM_CONFIG_HOME=/home/alpine/.config/helm \
    HELM_DATA_HOME=/home/alpine/.local/share/helm \
    HELM_CACHE_HOME=/home/alpine/.cache/helm

# Helm 4 requires plugin verification by default; helm-diff does not publish provenance metadata.
RUN helm plugin install https://github.com/databus23/helm-diff \
    --version v${HELM_DIFF_VERSION} \
    --verify=false

RUN kubectl version --client && \
    helm version --short && \
    helm plugin list

WORKDIR /home/alpine
