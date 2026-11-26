FROM alpine:3.22 AS game
ARG WEB_RELEASE_URL=https://github.com/9MidhunPM/Cindertrail/releases/download/web-43121ca/cindertrail-web.zip
ADD ${WEB_RELEASE_URL} /tmp/game.zip
WORKDIR /src
COPY deploy/web/prepare-game.sh deploy/web/prepare-game.sh
RUN mkdir -p showcase/game \
    && sh deploy/web/prepare-game.sh /tmp/game.zip \
    && for part in showcase/game/runtime/*.part*; do gzip -c "$part" > "$part.gz"; done

FROM node:24-alpine AS homepage
WORKDIR /src/web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
COPY media/Cindertrail_Gameplay.mp4 /src/media/
COPY media/screenshots/exploration.webp media/screenshots/shrine-defense.webp /src/media/screenshots/
COPY showcase/assets/fonts/ /src/showcase/assets/fonts/
RUN npm run build

FROM nginx:1.29-alpine
COPY showcase/ /usr/share/nginx/html/showcase/
COPY --from=game /src/showcase/game/runtime/ /usr/share/nginx/html/showcase/game/runtime/
COPY --from=homepage /src/web/dist/ /usr/share/nginx/html/
RUN mkdir /usr/share/nginx/html/play \
    && sed 's|<base href="./runtime/">|<base href="/showcase/game/runtime/">|' \
        /usr/share/nginx/html/showcase/game/index.html > /usr/share/nginx/html/play/index.html \
    && chmod -R a+rX /usr/share/nginx/html
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
RUN nginx -t
EXPOSE 80
