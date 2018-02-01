FROM alpine:latest

RUN apk update \
 && apk add jq \
 && rm -rf /var/cache/apk/*

RUN mkdir /app
ADD vault /app/vault
ADD run.sh /app/run.sh
WORKDIR /app
EXPOSE 8080
CMD ["/app/run.sh"]
