# Docker phpMyAdmin

[phpMyAdmin](https://github.com/phpmyadmin/phpmyadmin) running in Alpine linux with Nginx and PHP-FPM.

## Usage
```
docker run --name phpmyadmin -d -p 8080:8080 moonbuggy2000/phpmyadmin:latest
```

The default builds use the `all-languages` release. To save a few megabytes the English-only version is also available, tagged with the suffix `english`.

### Environment variables
Environmental variables can be specified with the `-e` flag. Available environmental variables are:

*   ``PMA_ARBITRARY``    - when set to `true` connection to an arbitrary server will be allowed
*   ``PMA_HOST``         - define address/host name of the MySQL server
*   ``PMA_VERBOSE``      - define verbose name of the MySQL server
*   ``PMA_PORT``         - define port of the MySQL server
*   ``PMA_HOSTS``        - define comma separated list of address/host names of the MySQL servers
*   ``PMA_VERBOSES``     - define comma separated list of verbose names of the MySQL servers
*   ``PMA_PORTS``        - define comma separated list of ports of the MySQL servers
*   ``PMA_USER``         - define username for MySQL server authentication
*   ``PMA_PASSWORD``     - define password for MySQL server authentication
*   ``PMA_ABSOLUTE_URI`` - define user-facing URI
*   ``PMA_SSL``          - set `true` enable SSL (default: `false`)
*   ``PMA_SSL_KEY``      - path to client key file (default: `/certs/client-key.pem`)
*   ``PMA_SSL_CERT``     - path to client certificate file (default: `/certs/client-cert.pem`)
*   ``PMA_SSL_CA``       - path to CA file (default: `/certs/server-ca.pem`)
*   ``PMA_SSL_CA_PATH``  - path to directory of trusted CA certificates (default: `/certs/ca/`)
*   ``PMA_SSL_CIPHERS``  - list of allowable ciphers (default: `NULL`)
*   ``PMA_SSL_VERIFY``   - enable SSL validation (default: `true`)
*   ``PMA_CONSOLE_DARKTHEME`` - dark theme for the console window (default: `false`)
*   ``NGINX_PORT``       - phpMyAdmin web interface port (default: `8080`)
*   ``PUID``             - user ID to run as
*   ``PGID``             - group ID to run as
*   ``TZ``               - timezone

This image should run basically the same way the official phpMyAdmin image does and a more detailed description is available on their [GitHub](https://github.com/phpmyadmin/docker) or [DockerHub](https://hub.docker.com/r/phpmyadmin/phpmyadmin) pages.

### Volumes
If you wish to configure phpMyAdmin through the config file rather than environment variables you can mount and edit `/etc/phpmyadmin/config.inc.php`.

To persist SSL keys/certificates `/certs` should be mounted.

### Example docker-compose.yml
This example assumes you have [Traefik v2](https://hub.docker.com/_/traefik) running in another container, ready to proxy. If you don't just remove the references to the `traefik` network.

```
version: '2'

services:
  mariadb:
    image: jbergstroem/mariadb-alpine:latest
    container_name: mariadb
    restart: unless-stopped
    ports:
      - 3306:3306
    volumes:
      - mariadb_data:/var/lib/mysql
    environment:
      - "MYSQL_DATABASE=phpmyadmin"
      - "MYSQL_USER=user"
      - "MYSQL_PASSWORD=password"
      - "MYSQL_ROOT_PASSWORD=rootpassword"
    networks:
      - mariadb
      - traefik

  phpmyadmin:
    image: moonbuggy2000/phpmyadmin:latest-english
    container_name: phpmyadmin
    depends_on:
      - mariadb
    restart: unless-stopped
    ports:
      - 8080:8080
    volumes:
      - phpmyadmin_certs:/certs
    environment:
      - "PMA_ABSOLUTE_URI=phpmyadmin.local"
      - "PMA_HOST=mariadb"
      - "PMA_PORT=3306"
      - "PMA_USER=user"
      - "PMA_PASSWORD=password"
      - "TZ=Australia/Sydney"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.phpmyadmin.rule=Host(`phpmyadmin.local`)"
      - "traefik.http.services.phpmyadmin.loadbalancer.server.port=8080"
    networks:
      - mariadb
      - traefik

volumes:
  mariadb_data:
    driver: local
    name: mariadb_data
  phpmyadmin_certs:
    driver: local
    name: phpmyadmin_certs

networks:
  mariadb:
    driver: bridge
    name: mariadb
  traefik:
    external:
      name: traefik
```

## Links
GitHub: <https://github.com/moonbuggy/docker-phpmyadmin>

Docker Hub: <https://hub.docker.com/r/moonbuggy2000/phpmyadmin>
