FROM barichello/godot-ci:4.7.2 AS export
WORKDIR /project
COPY . .
RUN mkdir -p /out && godot --headless --path /project --export-release "Web" /out/index.html

FROM nginx:1.29-alpine
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=export /out/ /usr/share/nginx/html/
EXPOSE 80
