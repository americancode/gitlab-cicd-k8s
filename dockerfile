# Use an alpine image

FROM alpine:3.22

 

# Install prerequisites

RUN apk update && \

    apk upgrade --no-cache && \

    apk add bash curl git ca-certificates yq

 

# Create a non-root user named alpine

RUN addgroup -g 1001 alpine && \

    adduser -u 1001 -G alpine -s /bin/bash -D alpine

 

# Give alpine user ownership/permissions for certificate directories

RUN chown -R alpine:alpine /usr/local/share/ca-certificates && \

    chown -R alpine:alpine /etc/ssl/certs && \

    chown alpine:alpine /etc/ca-certificates.conf && \

    chmod 755 /usr/local/share/ca-certificates && \

    chmod 755 /etc/ssl/certs

 

# Make update-ca-certificates accessible to alpine user

RUN chmod 755 /usr/sbin/update-ca-certificates

 

# Set desired versions

ENV KUBECTL_VERSION="1.33.3"

ENV HELM_VERSION="3.18.6"

 

# Install kubectl

RUN curl -LO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \

    chmod +x kubectl && \

    mv kubectl /usr/local/bin/

 

# Install helm

RUN curl -LO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz && \

    tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \

    mv linux-amd64/helm /usr/local/bin/helm && \

    rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz

 

# Create helm cache directory with proper permissions

RUN mkdir -p /home/alpine/.cache/helm && \

    mkdir -p /home/alpine/.config/helm && \

    chown -R alpine:alpine /home/alpine

 

# Switch to non-root user

USER alpine

 

# Install helm-diff plugin

RUN helm plugin install https://github.com/databus23/helm-diff

 

# Verify installations

RUN kubectl version --client && \

    helm version --short && \

    helm plugin list

 

# Set working directory

WORKDIR /home/alpine