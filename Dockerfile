# syntax = docker/dockerfile:1.4.0

ARG PHP_VERSION="7.4"
ARG FROM_IMAGE="moonbuggy2000/alpine-s6-nginx-php-fpm:${PHP_VERSION}"

ARG PMA_VERSION="5.2.0"
ARG PMA_CONFIG_PATH="/etc/phpmyadmin"

# prepare files
#
ARG BUILDPLATFORM="linux/amd64"
FROM --platform="${BUILDPLATFORM}" moonbuggy2000/fetcher:latest AS fetcher

WORKDIR /build

ARG PMA_VERSION
ARG PMA_CONFIG_PATH
ARG PMA_LANGUAGES="all-languages"
RUN mkdir /s6/ \
	&& wget --no-check-certificate -qO- "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-${PMA_LANGUAGES}.tar.xz" \
		| tar --strip 1 -xJf - \
	&& rm -rf \
		composer.json \
		examples/ \
		po/ \
		RELEASE-DATE-${PMA_VERSION} \
		setup/ \
		test/ \
		>/dev/null 2>&1 \
	&& chown -R 1000:1000 /build

# the config file changes syntax at PMA v5.2.0
RUN if [ "$(echo "5.2.0 ${PMA_VERSION}" | xargs -n1 | sort -uV | tail -n1)" = "${PMA_VERSION}" ]; then \
			sed -e "s|('configFile'\s+=>\s+).*|\1'${PMA_CONFIG_PATH}/config.inc.php',|" -E -i libraries/vendor_config.php; \
		else \
			sed -e "s|(CONFIG_DIR',\s*)(.*)\)|\1'${PMA_CONFIG_PATH}/')|" -E -i libraries/vendor_config.php; \
		fi


## build the image
#
FROM "${FROM_IMAGE}" AS builder

ARG PMA_VERSION
ARG PMA_CONFIG_PATH
# use a local APK caching proxy, if one is provided
ARG APK_PROXY=""
RUN if [ ! -z "${APK_PROXY}" ]; then \
		alpine_minor_ver="$(grep -o 'VERSION_ID.*' /etc/os-release | grep -oE '([0-9]+\.[0-9]+)')"; \
    mv /etc/apk/repositories /etc/apk/repositories.bak; \
		echo "${APK_PROXY}/alpine/v${alpine_minor_ver}/main" >/etc/apk/repositories; \
		echo "${APK_PROXY}/alpine/v${alpine_minor_ver}/community" >>/etc/apk/repositories; \
	fi \
	&& apk --no-cache add \
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
		php7-zlib \
  && (mv /etc/apk/repositories.bak /etc/apk/repositories || true)

ARG WEB_ROOT="/var/www/html"
COPY --from=fetcher build/ "${WEB_ROOT}/"
COPY root/ /

RUN sed -e "s/BLOWFISH_SECRET/$(tr -dc 'a-zA-Z0-9~!@#%^&*_()+}{?><;.,[]=-' < /dev/urandom | fold -w 32 | head -n 1)/" \
		-i /etc/phpmyadmin/config.secret.inc.php \
	&& touch /etc/phpmyadmin/config.user.inc.php \
	&& mkdir /sessions \
	&& mkdir /certs \
	&& add-contenv \
			PMA_VERSION="${PMA_VERSION}" \
			PMA_CONFIG_PATH="${PMA_CONFIG_PATH}"

ARG NGINX_PORT="8080"
ENV NGINX_PORT="${NGINX_PORT}" \
	S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

EXPOSE "${NGINX_PORT}"

ENTRYPOINT ["/init"]
