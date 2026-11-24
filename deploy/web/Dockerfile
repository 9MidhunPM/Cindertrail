FROM alpine:3.22 AS game
ARG WEB_RELEASE_URL=https://github.com/9MidhunPM/Cindertrail/releases/download/web-43121ca/cindertrail-web.zip
ADD ${WEB_RELEASE_URL} /tmp/game.zip
WORKDIR /src
COPY deploy/web/prepare-game.sh deploy/web/prepare-game.sh
RUN mkdir -p showcase/game \
    && sh deploy/web/prepare-game.sh /tmp/game.zip \
    && for part in showcase/game/runtime/*.part*; do gzip -c "$part" > "$part.gz"; done

FROM nginx:1.29-alpine
COPY showcase/ /usr/share/nginx/html/
RUN chmod -R a+rX /usr/share/nginx/html
COPY --from=game /src/showcase/game/runtime/ /usr/share/nginx/html/game/runtime/
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
