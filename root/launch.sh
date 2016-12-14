#!/bin/bash

set -e

#set the DEBUG env variable to turn on debugging
[[ -n "$DEBUG" ]] && set -x

pid=0

# Required vars
HAPROXY_MODE=${HAPROXY_MODE:-consul}
HAPROXY_DOMAIN=${HAPROXY_DOMAIN:-haproxy.service.consul}
CONSUL_TEMPLATE=${CONSUL_TEMPLATE:-/usr/local/bin/consul-template}
CONSUL_CONFIG=${CONSUL_CONFIG:-/consul-template/config.d}
CONSUL_CONNECT=${CONSUL_CONNECT:-consul.service.consul:8500}
CONSUL_MINWAIT=${CONSUL_MINWAIT:-2s}
CONSUL_MAXWAIT=${CONSUL_MAXWAIT:-10s}
CONSUL_RETRY=${CONSUL_RETRY:-5s}
CONSUL_LOGLEVEL=${CONSUL_LOGLEVEL:-warn}
CONSUL_PRODUCTION=${CONSUL_PRODUCTION:-production}

# SIGTERM & SIGINT -handler
# https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86#.2rkt303t7
term_handler() {
  if [ $pid -ne 0 ]; then
    kill -s TERM "$pid"
    wait "$pid"
  fi
  exit 0; # we drop 0, because SIGINT is just a reload
}

reload_handler() {
  if [ $pid -ne 0 ]; then
    echo "sending HUP to $pid"
    kill -s HUP "$pid"
    wait "$pid"
  fi
}

launch_haproxy() {
    if [ "$(ls -A /usr/local/share/ca-certificates)" ]; then
        cat /usr/local/share/ca-certificates/* >> /etc/ssl/certs/ca-certificates.crt
    fi

    if [ -n "${CONSUL_TOKEN}" ]; then
        ctargs="${ctargs} -token ${CONSUL_TOKEN}"
    fi

    vars=$@

    if [ ! -f /consul-template/template.d/haproxy.tmpl ]; then
      ln -s /consul-template/template.d/${HAPROXY_MODE}.tmpl \
            /consul-template/template.d/haproxy.tmpl
    fi

    # Generate self-signed certificate, if required.
    if [ -n "${HAPROXY_USESSL}" -a ! -f /haproxy/ssl.crt ]; then
      openssl req -x509 -newkey rsa:2048 -nodes -keyout /haproxy/key.pem -out /haproxy/cert.pem -days 365 -sha256 -subj "/CN=*.${HAPROXY_DOMAIN}"
      cat /haproxy/cert.pem /haproxy/key.pem > /haproxy/ssl.crt
    fi

    # Remove haproxy PID file, in case we're restarting
    [ -f /var/run/haproxy.pid ] && rm /var/run/haproxy.pid

    # Force a template regeneration on restart (if this file hasn't changed,
    # consul-template won't run the 'optional command' and thus haproxy won't
    # be started)
    [ -f /haproxy/haproxy.cfg ] && rm /haproxy/haproxy.cfg

    ${CONSUL_TEMPLATE} \
      -config ${CONSUL_CONFIG} \
      -retry ${CONSUL_RETRY} \
      -log-level ${CONSUL_LOGLEVEL} \
      -wait ${CONSUL_MINWAIT}:${CONSUL_MAXWAIT} \
      -consul ${CONSUL_CONNECT} ${ctargs} ${vars} \
      & pid="$!" || exit 128;
}

launch_haproxy $@

# log some useful data
echo "consul running with pid $pid"

# sigterm / sigint handler
trap term_handler SIGTERM SIGINT
trap reload_handler SIGHUP

# wait indefinetely
while true
do
  tail -f /dev/null & wait ${!}
done
