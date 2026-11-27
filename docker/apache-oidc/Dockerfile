# Apache with mod_auth_openidc, the reverse proxy from issue #134. Debian's packages rather than a
# source build: the module version Debian ships is what most self-hosters actually run.
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends apache2 libapache2-mod-auth-openidc ca-certificates \
    && a2enmod auth_openidc headers proxy proxy_http \
    && a2dissite 000-default \
    && rm -rf /var/lib/apt/lists/*

COPY paperless.conf /etc/apache2/sites-enabled/paperless.conf

# apache2ctl reads APACHE_ARGUMENTS from the environment, which is how the compose file passes the
# -D switches that toggle the configurations under test.
CMD ["apache2ctl", "-D", "FOREGROUND"]
