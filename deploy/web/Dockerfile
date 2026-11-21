FROM nginx:1.29-alpine
ARG WEB_RELEASE_URL=https://github.com/9MidhunPM/Cindertrail/releases/download/web-43121ca/cindertrail-web.zip
RUN apk add --no-cache curl unzip \
    && curl --fail --location --retry 3 "$WEB_RELEASE_URL" -o /tmp/cindertrail-web.zip \
    && unzip -q /tmp/cindertrail-web.zip -d /usr/share/nginx/html \
    && rm /tmp/cindertrail-web.zip
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
