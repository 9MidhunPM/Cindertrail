#!/usr/bin/env bash
set -euo pipefail
umask 077

voice_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
voice_data="${XDG_DATA_HOME:-$HOME/.local/share}"
voice_cache="${XDG_CACHE_HOME:-$HOME/.cache}"

runtime_ready() {
    [[ -x "$1" && -r "$2/kokoro-v1.0.fp16.onnx" && -r "$2/voices-v1.0.bin" ]]
}

if [[ -n "${CINDERTRAIL_VOICE_PYTHON:-}" || -n "${CINDERTRAIL_VOICE_MODELS:-}" ]]; then
    voice_python="${CINDERTRAIL_VOICE_PYTHON:-$voice_data/cindertrail/mote-voice/venv/bin/python}"
    voice_models="${CINDERTRAIL_VOICE_MODELS:-$voice_cache/cindertrail/mote-voice}"
elif runtime_ready "$voice_data/cindertrail/mote-voice/venv/bin/python" "$voice_cache/cindertrail/mote-voice"; then
    voice_python="$voice_data/cindertrail/mote-voice/venv/bin/python"
    voice_models="$voice_cache/cindertrail/mote-voice"
elif runtime_ready "$voice_data/thursday/neural-venv/bin/python" "$voice_cache/thursday/voices/kokoro"; then
    voice_python="$voice_data/thursday/neural-venv/bin/python"
    voice_models="$voice_cache/thursday/voices/kokoro"
else
    voice_python="$HOME/.local/share/thursday/neural-venv/bin/python"
    voice_models="$HOME/.cache/thursday/voices/kokoro"
fi

if ! runtime_ready "$voice_python" "$voice_models"; then
    exit 1
fi
if [[ "${1:-}" == --check && "$#" == 1 ]]; then
    exec "$voice_python" -c 'import kokoro_onnx, onnxruntime, numpy' >/dev/null 2>&1
fi
if [[ "$#" != 2 ]]; then
    printf '%s\n' 'Usage: synthesize.sh INPUT OUTPUT | synthesize.sh --check' >&2
    exit 2
fi
exec "$voice_python" "$voice_dir/synthesize.py" --models "$voice_models" --input "$1" --output "$2"
