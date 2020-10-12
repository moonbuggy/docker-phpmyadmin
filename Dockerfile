ARG PHP_VERSION=7.3
ARG PMA_VERSION=5.0.3

ARG PMA_CONFIG_PATH=/etc/phpmyadmin/

# prepare files
#
FROM alpine:3.11 as builder

ARG PMA_VERSION
ARG PMA_CONFIG_PATH

WORKDIR /build

RUN apk --no-cache add \
		curl

RUN curl -sS -o phpMyAdmin.tar.xz -L https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.tar.xz \
	&& tar -xf phpMyAdmin.tar.xz --strip 1 \
	&& rm -f phpMyAdmin.tar.xz \
	&& rm -rf \
		composer.json \
		examples/ \
		po/ \
		RELEASE-DATE-${PMA_VERSION} \
		setup/ \
		test/ \
	&& sed -e "s|(CONFIG_DIR',\s*)(.*)\)|\1'${PMA_CONFIG_PATH}')|" -E -i libraries/vendor_config.php \
	&& chown -R 1000:1000 /build

# build the final image
#
FROM moonbuggy2000/alpine-s6-nginx-php-fpm:php${PHP_VERSION}

ARG PMA_VERSION
ARG PMA_CONFIG_PATH

COPY --from=builder build/ ${WEB_ROOT}/
COPY ./etc/ /etc/

RUN add-contenv \
		PMA_VERSION=${PMA_VERSION} \
		PMA_CONFIG_PATH=${PMA_CONFIG_PATH} \
	&& apk --no-cache add \
		curl \
		libzip \
		php7-bz2 \
		php7-ctype \
		php7-curl \
		php7-dom \
		php7-gd \
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
	&& sed -i "s/BLOWFISH_SECRET/$(tr -dc 'a-zA-Z0-9~!@#%^&*_()+}{?><;.,[]=-' < /dev/urandom | fold -w 32 | head -n 1)/" /etc/phpmyadmin/config.secret.inc.php \
	&& touch /etc/phpmyadmin/config.user.inc.php \
	&& mkdir -p /var/nginx/client_body_temp \
	&& mkdir /sessions

EXPOSE 8080
