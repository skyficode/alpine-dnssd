

FROM alpine

# install a syslog service to keep mDNSResponder code happy
#RUN echo '*.* -/dev/stdout' > /etc/rsyslog.conf
#COPY /etc/rsyslog.d/rsyslog.conf <<EOF \
#    $ModLoad imudp \
#    $UDPServerAddress 0.0.0.0 \
#    $UDPServerRun 514 \
#    $IncludeConfig /etc/rsyslog.d/*.conf \
#    & ~ \
#EOF

# add packages
RUN apk add --no-cache tini gettext libdispatch musl-nscd mbedtls-utils 
# remove inetutils-syslogd since apple-dnssd now shouldn't need /dev/log from syslogd

# add dnssd-proxy and mdnsd and libs
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/ServiceRegistration/build/dnssd-proxy /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/mDNSPosix/build/prod/mdnsd /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/mDNSPosix/build/prod/libdns_sd.so /usr/local/lib/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/mDNSPosix/build/prod/libnss_mdns-0.2.so /usr/local/lib/

# add tools
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/Clients/build/dns-sd /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/mDNSPosix/build/prod/mDNSNetMonitor /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/ServiceRegistration/build/keydump /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/ServiceRegistration/build/srp-client /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/ServiceRegistration/build/srputil /usr/local/bin/

# part of Apple mDNSResponder code, but not needed except for expirimentation
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/ServiceRegistration/build/srp-mdns-proxy /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/ServiceRegistration/build/cti-server /usr/local/bin/
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/mDNSPosix/build/prod/dnsextd /usr/local/bin
COPY --from=ghcr.io/skyficode/apple-dnssd:main /usr/src/mDNSResponder/mDNSShared/dnsextd.conf /etc/dnsextd.conf.example

# add init script (uses tini to starts both mdnsd and dnssd-proxy)
COPY init-dnssd-proxy.sh /app/
RUN chmod a+x /app/init-dnssd-proxy.sh 

ENTRYPOINT ["/sbin/tini", "--", "/app/init-dnssd-proxy.sh"]




