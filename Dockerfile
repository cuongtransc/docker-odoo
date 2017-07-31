# Author: Cuong Tran
#
# Build: docker build -t cuongtransc/app:0.1 .
# Run: docker run -d -p 8080:8080 --name app-run cuongtransc/app:0.1
#
# References: https://github.com/odoo/docker
#

FROM debian:jessie

# MAINTAINER Odoo S.A. <info@odoo.com>
MAINTAINER Cuong Tran "cuongtransc@gmail.com"

## using apt-cacher-ng proxy for caching deb package
RUN echo 'Acquire::http::Proxy "http://172.17.0.1:3142/";' > /etc/apt/apt.conf.d/01proxy

#ENV REFRESHED_AT 2017-02-10
#RUN apt-get update -qq

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            node-less \
            python-gevent \
            python-pip \
            python-renderpm \
            python-support \
            python-watchdog \
        && curl -o wkhtmltox.deb -SL http://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-amd64.deb \
        && echo '40e8b906de658a2221b15e4e8cd82565a47d7ee8 wkhtmltox.deb' | sha1sum -c - \
        && dpkg --force-depends -i wkhtmltox.deb \
        && apt-get -y install -f --no-install-recommends \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false npm \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
        && pip install psycogreen==1.0

# Install Odoo
ENV ODOO_VERSION 10.0
ENV ODOO_RELEASE 20170207
RUN set -x; \
        curl -o odoo.deb -SL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
        && echo '5d2fb0cc03fa0795a7b2186bb341caa74d372e82 odoo.deb' | sha1sum -c - \
        && dpkg --force-depends -i odoo.deb \
        && apt-get update \
        && apt-get -y install -f --no-install-recommends \
        && rm -rf /var/lib/apt/lists/* odoo.deb

# Install python library for read Excel
RUN apt-get update \
    && apt-get install -y python-xlrd

ENV GOSU_VERSION 1.10

# Install gosu
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    && set -x \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get purge --auto-remove -y wget

RUN echo 'odoo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN chown root:users /usr/local/bin/gosu \
    && chmod ug+s /usr/local/bin/gosu

# Copy entrypoint script and Odoo configuration file
COPY ./docker-entrypoint.sh /

COPY ./configs/odoo.conf /srv/default_configs/odoo.conf
COPY ./configs/odoo.conf /etc/odoo/odoo.conf

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN mkdir -p /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Expose Odoo services
EXPOSE 8069 8071

# Set default user when running the container
USER odoo

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["odoo"]
