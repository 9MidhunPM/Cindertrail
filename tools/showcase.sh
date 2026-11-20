#!/usr/bin/env bash
set -euo pipefail

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$project/evidence/showcase"
godot_binary="${GODOT:-godot}"
headless=false
voice=true
journey_args=()

for option in "$@"; do
    case $option in
        --help)
            printf '%s\n' 'Usage: tools/showcase.sh [--once | --cycles=N] [--smoke] [--silent-voice] [--out=DIR]' \
                'The native showcase loops by default. Press Escape to exit.' \
                'Use --smoke for a faster headless playthrough. If no cycle count is supplied, it runs once.'
            exit 0
            ;;
        --once)
            journey_args+=("$option")
            ;;
        --cycles=*)
            count=${option#--cycles=}
            if [[ ! "$count" =~ ^[1-9][0-9]*$ ]]; then
                printf 'Cycle count must be a positive integer\n' >&2
                exit 2
            fi
            journey_args+=("$option")
            ;;
        --out=*)
            output=$(realpath -m -- "${option#--out=}")
            ;;
        --smoke)
            headless=true
            ;;
        --silent-voice)
            voice=false
            ;;
        *)
            printf 'Unknown option %s\n' "$option" >&2
            exit 2
            ;;
    esac
done

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export XDG_DATA_HOME="$scratch/data"
export XDG_CONFIG_HOME="$scratch/config"
export XDG_CACHE_HOME="$scratch/cache"
export CINDERTRAIL_SHOWCASE_ISOLATED=1
export CINDERTRAIL_GUIDE_ONLINE=0
export OPENAI_API_KEY=''
run_args=(--path "$project" --script res://tools/qa/showcase.gd)
if "$headless"; then
    run_args+=(--headless --fixed-fps 60)
    if (( ${#journey_args[@]} == 0 )); then
        journey_args+=(--once)
    fi
fi
if ! "$voice"; then
    journey_args+=(--silent-voice)
fi

"$godot_binary" "${run_args[@]}" -- "--out=$output" "${journey_args[@]}"
