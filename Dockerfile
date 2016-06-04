FROM gliderlabs/alpine:3.4

MAINTAINER Vitaly Aminev <v@makeomatic.ru>

ENV CONSUL_TEMPLATE_VERSION=0.14.0 \
    HAPROXY_MAJOR=1.6 \
    HAPROXY_VERSION=1.6.5 \
    HAPROXY_MD5=5290f278c04e682e42ab71fed26fc082

# see http://sources.debian.net/src/haproxy/1.5.8-1/debian/rules/ for some helpful navigation of the possible "make" arguments
RUN set -x \
	&& apk add --no-cache --update --virtual .build-deps \
		curl \
		gcc \
		libc-dev \
		linux-headers \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
    wget \
    zip \
	&& curl -SL "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" -o haproxy.tar.gz \
	&& echo "${HAPROXY_MD5}  haproxy.tar.gz" | md5sum -c \
	&& mkdir -p /usr/src \
	&& tar -xzf haproxy.tar.gz -C /usr/src \
	&& mv "/usr/src/haproxy-$HAPROXY_VERSION" /usr/src/haproxy \
	&& rm haproxy.tar.gz \
	&& make -C /usr/src/haproxy \
		TARGET=linux2628 \
		USE_PCRE=1 PCREDIR= \
		USE_OPENSSL=1 \
		USE_ZLIB=1 \
		all \
		install-bin \
	&& mkdir -p /usr/local/etc/haproxy \
	&& cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
	&& rm -rf /usr/src/haproxy \
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
  && wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
  && unzip /consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
  && mv /consul-template /usr/local/bin/consul-template \
  && rm -rf /consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
  && mkdir /haproxy \
	&& apk add --virtual .haproxy-rundeps $runDeps \
	&& apk del .build-deps

VOLUME ["/consul-template", "/haproxy"]

COPY root /

EXPOSE 80 443 8443

CMD ["/launch.sh"]
