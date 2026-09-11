# Temporary workaround: build helm-diff locally until its upstream binary is
# built with a patched Go toolchain. This removes the HIGH findings previously
# reported in the v3.15.13 binary:
# CVE-2026-33818, CVE-2026-39821, CVE-2026-39822, CVE-2026-46600,
# CVE-2026-56853, CVE-2026-56858, CVE-2026-56859, CVE-2026-56860,
# CVE-2026-56862.
# The MEDIUM SSH findings are from golang.org/x/crypto v0.55.0:
# CVE-2026-56855 and CVE-2026-78662. Remove this stage when upstream ships
# a helm-diff release containing the patched dependencies.
FROM golang:1.27.1-alpine AS tools-builder

ARG HELM_DIFF_VERSION=3.15.13
ARG HELM_VERSION=4.3.0

RUN apk add --no-cache git
WORKDIR /src/helm-diff
RUN git clone --depth 1 --branch "v${HELM_DIFF_VERSION}" https://github.com/databus23/helm-diff.git . && \
    go mod edit -require=golang.org/x/crypto@v0.56.0 && \
    go mod tidy && \
    CGO_ENABLED=0 go build -trimpath \
    -ldflags="-X github.com/databus23/helm-diff/v3/cmd.Version=${HELM_DIFF_VERSION}" \
    -o /out/diff

# Temporary workaround: build Helm from source until an upstream binary uses
# golang.org/x/crypto v0.56.0. This addresses CVE-2026-56855 and
# CVE-2026-78662, the remaining MEDIUM SSH findings in the official binary.
WORKDIR /src/helm
RUN git clone --depth 1 --branch "v${HELM_VERSION}" https://github.com/helm/helm.git . && \
    go mod edit -require=golang.org/x/crypto@v0.56.0 && \
    go mod tidy
RUN CGO_ENABLED=0 go build -mod=mod -trimpath -o /out/helm ./cmd/helm

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

# The old direct Helm download is intentionally retained here as comments for
# reference. The source-built binary above is used instead.
# RUN curl --fail --show-error --silent --location -o helm-v${HELM_VERSION}-linux-amd64.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
#     curl --fail --show-error --silent --location -o helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" && \
#     sha256sum -c helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum && \
#     tar -zxf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
#     mv linux-amd64/helm /usr/local/bin/helm && \
#     rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum
COPY --from=tools-builder /out/helm /usr/local/bin/helm

RUN mkdir -p /home/alpine/.cache/helm /home/alpine/.config/helm && \
    chown -R alpine:alpine /home/alpine

ENV HELM_CONFIG_HOME=/home/alpine/.config/helm \
    HELM_DATA_HOME=/home/alpine/.local/share/helm \
    HELM_CACHE_HOME=/home/alpine/.cache/helm

# Helm 4 requires plugin verification by default; helm-diff does not publish provenance metadata.
RUN mkdir -p /home/alpine/.local/share/helm/plugins/helm-diff/bin
COPY --from=tools-builder /out/diff /home/alpine/.local/share/helm/plugins/helm-diff/bin/diff
COPY --from=tools-builder /src/helm-diff/plugin.yaml /home/alpine/.local/share/helm/plugins/helm-diff/plugin.yaml
RUN chown -R alpine:alpine /home/alpine/.local/share/helm

USER alpine

RUN kubectl version --client && \
    helm version --short && \
    helm plugin list

WORKDIR /home/alpine
