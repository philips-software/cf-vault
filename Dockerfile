FROM alpine:latest
RUN mkdir /apps
ADD vault /apps/vault
ADD run.sh /apps/run.sh
WORKDIR /apps
EXPOSE 8080
CMD ["/apps/run.sh"]
