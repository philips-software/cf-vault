FROM alpine:latest AS builder
ENV VAULT_VERSION 1.8.4


WORKDIR /vault
RUN apk add --no-cache git openssh gcc musl-dev curl gnupg unzip

# Download Vault and verify checksums (https://www.hashicorp.com/security.html)
COPY resources/hashicorp.asc /tmp/
ADD run.sh /vault
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
COPY --from=builder /vault/run.sh /app
COPY resources/vault-schema.sql /app
EXPOSE 8080
CMD ["/app/run.sh"]
