FROM golang:1.22.2 AS builder
ENV VAULT_VERSION 1.14.10


WORKDIR /vault
RUN apt update && \
    apt install -y git openssh-server gcc musl-dev curl gnupg unzip

# Download Vault and verify checksums (https://www.hashicorp.com/security.html)
COPY resources/hashicorp.asc /tmp/
ADD run.sh /vault

# Build vault-auth-cf-plugin
RUN go install github.com/mitchellh/gox@latest && \
    git clone https://github.com/hashicorp/vault-plugin-auth-cf.git && \
    cd vault-plugin-auth-cf && \
    make test && \
    make dev && \
    make tools

# Keep the checksum in a file to be used for plugin registration
RUN sha256sum /vault/vault-plugin-auth-cf/bin/vault-plugin-auth-cf > checksum

# Fix exec permissions issue that come up due to the way source controls deal with executable files.
RUN chmod a+x /vault/run.sh

RUN gpg --import /tmp/hashicorp.asc
RUN curl -Os https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip 
RUN curl -Os https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS 
RUN curl -Os https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig

# Verify the signature file is untampered.
RUN gpg --verify vault_${VAULT_VERSION}_SHA256SUMS.sig vault_${VAULT_VERSION}_SHA256SUMS
# The checksum file has all platforms, we are interested in only linux x64, so only check that one.
RUN grep -E '_linux_amd64' < vault_${VAULT_VERSION}_SHA256SUMS | sha256sum -c
RUN unzip vault_${VAULT_VERSION}_linux_amd64.zip

FROM alpine:latest 
LABEL maintainer="Andy Lo-A-Foe <andy.lo-a-foe@philips.com>"
RUN apk add --no-cache jq ca-certificates curl postgresql-client

WORKDIR /app
COPY --from=builder /vault/vault /app
COPY --from=builder /vault/vault-plugin-auth-cf/bin/vault-plugin-auth-cf /app/plugins/
COPY --from=builder /vault/run.sh /app
COPY --from=builder /vault/checksum /app/checksum
COPY resources/vault-schema.sql /app
EXPOSE 8080
CMD ["/app/run.sh"]
