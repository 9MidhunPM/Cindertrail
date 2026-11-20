#!/usr/bin/env bash
set -euo pipefail
umask 077

voice_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if "$voice_dir/synthesize.sh" --check; then
    printf '%s\n' 'The local Mote voice runtime is available.'
    exit 0
fi
if ! command -v uv >/dev/null || ! command -v curl >/dev/null; then
    printf '%s\n' 'Install uv and curl before setting up the local Mote voice.' >&2
    exit 1
fi

voice_data="${XDG_DATA_HOME:-$HOME/.local/share}/cindertrail/mote-voice"
voice_models="${XDG_CACHE_HOME:-$HOME/.cache}/cindertrail/mote-voice"
model_release="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1"
mkdir -p -- "$voice_data" "$voice_models"

download_model() {
    local name=$1 expected=$2 target
    target="$voice_models/$name"
    if [[ -f "$target" ]] && printf '%s  %s\n' "$expected" "$target" | sha256sum --check --status; then
        return
    fi
    voice_temp=$(mktemp "$voice_models/.incoming.XXXXXX")
    curl --fail --location --retry 2 --connect-timeout 15 "$model_release/$name" --output "$voice_temp"
    printf '%s  %s\n' "$expected" "$voice_temp" | sha256sum --check --status
    mv -- "$voice_temp" "$target"
    voice_temp=""
}

voice_temp=""
trap 'if [[ -n "$voice_temp" ]]; then rm -f -- "$voice_temp"; fi' EXIT
download_model kokoro-v1.0.fp16.onnx f3a290d384fbb27966d462905c71a46cef9e5fd00516b40df32a0b4afe77ac96
download_model voices-v1.0.bin bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d
uv venv --allow-existing --python 3.13 "$voice_data/venv"
uv pip install --python "$voice_data/venv/bin/python" 'kokoro-onnx==0.6.1' 'onnxruntime==1.31.0' 'numpy==2.5.4'
"$voice_dir/synthesize.sh" --check
printf '%s\n' 'Mote can now synthesize dialogue locally.'
