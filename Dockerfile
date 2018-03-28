FROM alpine:latest AS builder
ENV VAULT_VERSION 0.9.6

WORKDIR /vault
RUN apk update \
 && apk add curl \
 && apk add unzip 
RUN curl https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip -o vault.zip
RUN unzip vault.zip

FROM alpine:latest 
MAINTAINER Andy Lo-A-Foe <andy.lo-a-foe@philips.com>
RUN apk update \
 && apk add jq \
 && rm -rf /var/cache/apk/*

WORKDIR /app
COPY --from=builder /vault/vault /app
ADD run.sh /app/run.sh
EXPOSE 8080
CMD ["/app/run.sh"]
