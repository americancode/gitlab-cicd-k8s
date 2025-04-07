# Use an alpine image
FROM alpine:3.21.3

# Install prerequisites
RUN apk update && \
    apk upgrade --no-cache && \
    apk add curl git ca-certificates

RUN update-ca-certificates

RUN curl -LO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz

# Set desired versions
ENV KUBECTL_VERSION="1.31.4"
ENV HELM_VERSION="3.17.0"

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install helm
RUN curl -LO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz

# Install helm-diff plugin
RUN helm plugin install https://github.com/databus23/helm-diff

# Verify installations
RUN kubectl version --client && \
    helm version --short && \
    helm plugin list
