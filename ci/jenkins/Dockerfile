FROM jenkins/jenkins:lts-jdk17
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake cppcheck curl maven docker.io ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*
# kubectl, trivy, gitleaks (pinned versions: bump deliberately)
ARG KUBECTL_VERSION=v1.31.0
ARG TRIVY_VERSION=0.55.0
ARG GITLEAKS_VERSION=8.18.4
RUN curl -fsSL -o /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz | tar -xz -C /usr/local/bin trivy \
    && curl -fsSL https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz | tar -xz -C /usr/local/bin gitleaks
RUN jenkins-plugin-cli --plugins workflow-aggregator git github junit timestamps
USER jenkins
