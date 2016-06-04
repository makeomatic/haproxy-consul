FROM gliderlabs/alpine:3.4

MAINTAINER Vitaly Aminev <v@makeomatic.ru>

ENV CONSUL_TEMPLATE_VERSION=0.14.0

RUN apk --no-cache --update add bash haproxy ca-certificates zip wget && \
  wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
  unzip /consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip  && \
  mv /consul-template /usr/local/bin/consul-template && \
  rm -rf /consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
  apk del zip wget && \
  mkdir -p /haproxy

VOLUME ["/consul-template"]

COPY root /

CMD ["/launch.sh"]
