# Use the official Ubuntu base image
FROM ubuntu:latest

# Set environment variables to non-interactive to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    ca-certificates

# Install kubectl
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Helm-Diff Plugin
RUN helm plugin install https://github.com/databus23/helm-diff

# Set the default command to bash
CMD ["bash"]
