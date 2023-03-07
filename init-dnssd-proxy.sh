#!/usr/bin/env sh
set -e

# provide DNS-SD results based on mDNS, and proxy normal DNS to resolve.conf

echo "** Startup DNS-SD Domain Proxy **"

# process args 
export MDNS_DOMAIN=${MDNS_DOMAIN:=service.home.arpa}
export DNS_NAME=${DNS_NAME:=`hostname -s`.home.arpa}   
export LISTEN_ADDR=${LISTEN_ADDR:=`hostname -i`}
export UDP_PORT=${UDP_PORT:=53}
export TCP_PORT=${TCP_PORT:=53}
export TLS_PORT=${TLS_PORT:=853}

# in alpine on RouterOS, interface can only be eth1 today
# export MDNS_INTERFACE=${MDNS_INTERFACE:=`ip route get 1.0.0.0 | head -1 | cut -d' ' -f5`}
export MDNS_INTERFACE=${MDNS_INTERFACE:=eth1}
echo "- Using mDNS .local map to DNS-SD $MDNS_DOMAIN on $MDNS_INTERFACE"


# re-create the config file at container startup
echo "- Creating /etc/dnssd-proxy.cf file for $DNS_NAME to listen on $LISTEN_ADDR:$UDP_PORT" 
envsubst > /etc/dnssd-proxy.cf << "EOF"
interface $MDNS_INTERFACE $MDNS_DOMAIN
my-name $DNS_NAME
listen-addr $LISTEN_ADDR
udp-port $UDP_PORT
tcp-port $TCP_PORT
tls-port $TLS_PORT
EOF


# create key/cert, if none OR old
export DNSSD_PROXY_DIR=${DNSSD_PROXY_DIR:=/etc/dnssd-proxy}
# (DNSSD_PROXY_CERT_EXP = 180 days)
export DNSSD_PROXY_CERT_EXP=$( date '+%Y%m%d%H%M%S' -d@"$(( `date +%s`+60*60*24*180))" )
export DNSSD_PROXY_CERT_ISS=$( date '+%Y%m%d%H%M%S' )
mkdir -p $DNSSD_PROXY_DIR 
# (skip create if exists & never than 90 days)
if [ ! -f $DNSSD_PROXY_DIR/server.key ] || test `find $DNSSD_PROXY_DIR/server.key -ctime +90` ; then
    echo "- No server.key found (or old), recreating in $DNSSD_PROXY_DIR" 
    (cd $DNSSD_PROXY_DIR;
    gen_key type=rsa rsa_keysize=4096 filename=server.key)
fi
# (skip create if exists & never than 90 days)
if [ ! -f $DNSSD_PROXY_DIR/server.crt ] || test `find $DNSSD_PROXY_DIR/server.key -ctime +90` ; then
    echo "- No server.crt found (or old), recreating in $DNSSD_PROXY_DIR" 
    (cd $DNSSD_PROXY_DIR;
    cert_write selfsign=1 issuer_key=server.key issuer_name=CN=$DNS_NAME not_before=$DNSSD_PROXY_CERT_ISS not_after=$DNSSD_PROXY_CERT_EXP  is_ca=1 max_pathlen=0 output_file=server.crt )
fi

# start mDNS listener (daemon mode is automatic)
echo "== Starting mdnsd on default port 5353 =="
mdnsd

echo "== Starting starting syslogd =="
syslogd

echo "== Starting dnssd-proxy on udp $UDP_PORT tcp $TCP_PORT tls $TLS_PORT =="
dnssd-proxy >> /proc/1/fd/1 &

wait -n

