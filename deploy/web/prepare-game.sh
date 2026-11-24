#!/bin/sh
# Install the official single-threaded Godot release into the static showcase.
# An optional local ZIP avoids downloading the same release on an offline build.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
release=https://github.com/9MidhunPM/Cindertrail/releases/download/web-43121ca/cindertrail-web.zip
digest=2c1f1f9051cc6e9c12b2fd93eec2f9cac1166f7654ae9a46bfaa5a3c59e73aa6
game_dir=$root/showcase/game
stage=$(mktemp -d "$game_dir/.prepare.XXXXXX")
trap 'rm -rf "$stage"' EXIT
archive=${1:-}
if [ -z "$archive" ]; then
    archive=$stage/game.zip
    curl --fail --location --retry 3 "$release" --output "$archive"
fi
printf '%s  %s\n' "$digest" "$archive" | sha256sum -c -
unzip -q "$archive" index.js index.wasm index.pck 'index.audio*.js' -d "$stage"
# Static hosts commonly cap individual files at 25 MiB. The engine loader reads
# each file as a stream of these smaller pieces (see showcase/game/parts.js).
chunk_bytes=16777216
wasm_bytes=$(wc -c < "$stage/index.wasm")
pack_bytes=$(wc -c < "$stage/index.pck")
for name in index.wasm index.pck; do
    split -b "$chunk_bytes" -a 2 "$stage/$name" "$stage/chunk-"
    index=0
    for part in "$stage"/chunk-*; do
        mv "$part" "$stage/$name.part$(printf '%02d' "$index")"
        index=$((index + 1))
    done
    rm "$stage/$name"
done
printf 'const releaseFiles = { chunkBytes: %s, sizes: { "index.wasm": %s, "index.pck": %s } };\n' \
    "$chunk_bytes" "$wasm_bytes" "$pack_bytes" > "$stage/index.files.js"
# Pass a scoped fetch adapter to the release, without changing the browser's fetch.
{ printf '(function (fetch) {\n'; cat "$stage/index.js"; printf '\n})(fetchReleaseFile);\n'; } > "$stage/engine.tmp"
mv "$stage/engine.tmp" "$stage/index.js"
# Only expose verified, completely extracted files to an existing player.
mkdir -p "$game_dir/runtime"
for file in "$stage"/index.*; do
    mv "$file" "$game_dir/runtime/"
done
