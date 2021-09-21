ARG PHP_VERSION="7.4"
ARG FROM_IMAGE="moonbuggy2000/alpine-s6-nginx-php-fpm:${PHP_VERSION}"

ARG PMA_VERSION="5.1.0"
ARG PMA_CONFIG_PATH="/etc/phpmyadmin/"

ARG TARGET_ARCH_TAG="amd64"

# prepare files
#
FROM moonbuggy2000/fetcher:latest AS fetcher

WORKDIR /build

ARG PMA_VERSION
ARG PMA_CONFIG_PATH
RUN mkdir /s6/ \
	&& wget --no-check-certificate -qO- "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.tar.xz" \
		| tar --strip 1 -xJf - \
	&& rm -rf \
		composer.json \
		examples/ \
		po/ \
		RELEASE-DATE-${PMA_VERSION} \
		setup/ \
		test/ \
		>/dev/null 2>&1 \
	&& sed -e "s|(CONFIG_DIR',\s*)(.*)\)|\1'${PMA_CONFIG_PATH}')|" -E -i libraries/vendor_config.php \
	&& chown -R 1000:1000 /build

## build the image
#
FROM "${FROM_IMAGE}" AS builder

# QEMU static binaries from pre_build
ARG QEMU_DIR
ARG QEMU_ARCH=""
COPY _dummyfile "${QEMU_DIR}/qemu-${QEMU_ARCH}-static*" /usr/bin/

ARG PMA_VERSION
ARG PMA_CONFIG_PATH
RUN apk --no-cache add \
		curl \
		libzip \
		php7-bz2 \
		php7-ctype \
		php7-curl \
		php7-dom \
		php7-gd \
		php7-iconv \
		php7-intl \
		php7-json \
		php7-mbstring \
		php7-mysqli \
		php7-openssl \
		php7-phar \
		php7-session \
		php7-xml \
		php7-xmlreader \
		php7-zip \
		php7-zlib

ARG WEB_ROOT="/var/www/html"
COPY --from=fetcher build/ "${WEB_ROOT}/"
COPY ./etc /etc

RUN sed -e "s/BLOWFISH_SECRET/$(tr -dc 'a-zA-Z0-9~!@#%^&*_()+}{?><;.,[]=-' < /dev/urandom | fold -w 32 | head -n 1)/" \
		-i /etc/phpmyadmin/config.secret.inc.php \
	&& touch /etc/phpmyadmin/config.user.inc.php \
	&& mkdir /sessions \
	&& add-contenv \
			PMA_VERSION="${PMA_VERSION}" \
			PMA_CONFIG_PATH="${PMA_CONFIG_PATH}"

RUN rm -f "/usr/bin/qemu-${QEMU_ARCH}-static" > /dev/null 2>&1


## drop the QEMU binaries
#
FROM "moonbuggy2000/scratch:${TARGET_ARCH_TAG}"

COPY --from=builder / /

ARG NGINX_PORT="8080"
EXPOSE "${NGINX_PORT}"

ENTRYPOINT ["/init"]

HEALTHCHECK --start-period=10s --timeout=10s \
	CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/fpm-ping && echo 'okay' || exit 1
