#!/usr/bin/env python3
"""Render Mote's stock guide lines with Kokoro and write their exact-caption index."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import wave

import numpy as np
import onnxruntime as ort
from kokoro_onnx import Kokoro


AUDIO = Path(__file__).resolve().parent
PROJECT = AUDIO.parents[2]
VOICE = "af_heart"
SPEED = 1.4


def corpus():
    result = {}
    sites = {
        "grove": "grove",
        "quarry": "quarry",
        "relay": "relay",
        "wood": "lanternwood",
        "aqueduct": "sunken_aqueduct",
        "observatory": "sunwatch",
        "lantern": "frontier",
    }
    for key, file in sites.items():
        site_data = (PROJECT / f"data/sites/{file}.tres").read_text(encoding="utf-8")
        site = re.search(r'^label = "([^"]+)"', site_data, re.M)[1]
        objective = f"Unfold the shrine at {site}."
        compass = f"{objective} The compass will lead us along the trail."
        result[f"intro-{key}"] = f"I'm Mote. {compass}"
        result[f"travel-{key}"] = compass
        result[f"near-{key}"] = (
            f"We're close. {objective} Step up to the stone marker and interact to unfold the sun."
        )

    landmarks = (PROJECT / "scripts/world/camp_landmarks.gd").read_text(encoding="utf-8")
    for index, (title, detail) in enumerate(
        re.findall(r'"title": "([^"]+)",\s*"detail": "([^"]+)"', landmarks), 1
    ):
        result[f"landmark-{index:02}"] = f"{title.rstrip('.')}. {detail}"
    assert len([key for key in result if key.startswith("landmark-")]) == 7

    guide = (PROJECT / "scripts/companion/mote_guide.gd").read_text(encoding="utf-8")
    prefixes = {
        "intro": "I'm Mote. Follow",
        "defenses": "Let's cover the approaches.",
        "breather": "A breath between waves.",
        "last-light": "The sun can barely hold!",
        "pursuit": "Something followed us out.",
        "spent": "This camp has given us all its light.",
        "summit": "This is Vesper's perch.",
        "vesper-down": "Vesper is down.",
        "beacon": "The sun is whole.",
        "finish": "The beacon is clear.",
        "raid": "They're coming!",
        "pack": "Keep holding pack.",
    }
    for key, prefix in prefixes.items():
        matches = re.findall(r'return "(' + re.escape(prefix) + r'[^"]*)"', guide)
        assert len(matches) == 1, (key, matches)
        result[key] = matches[0]
    guardian = (PROJECT / "scripts/combat/vesper_colossus.gd").read_text(encoding="utf-8")
    action = guardian.split("func guide_action() -> String:", 1)[1].split("\nfunc ", 1)[0]
    for index, line in enumerate(re.findall(r'return "([^"]+)"', action), 1):
        result[f"vesper-{index:02}"] = line
    return result


def render(engine, line, target):
    samples, rate = engine.create(line, voice=VOICE, speed=SPEED, lang="en-us")
    if rate != 24000 or samples.ndim != 1 or not np.isfinite(samples).all() or not np.any(samples):
        raise ValueError(f"Invalid audio for {target.stem}")
    with tempfile.TemporaryDirectory(dir=target.parent, prefix=".mote-render-") as scratch:
        source = Path(scratch) / "speech.wav"
        encoded = Path(scratch) / "speech.ogg"
        pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes()
        with wave.open(str(source), "wb") as output:
            output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            output.writeframes(pcm)
        subprocess.run(
            ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(source),
             "-c:a", "libvorbis", "-q:a", "5", str(encoded)],
            check=True,
        )
        encoded.replace(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model_dir", type=Path)
    parser.add_argument("--force", action="store_true", help="re-render existing files")
    args = parser.parse_args()
    ort.disable_telemetry_events()
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    options.log_severity_level = 4
    session = ort.InferenceSession(
        str(args.model_dir / "kokoro-v1.0.fp16.onnx"), sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    engine = Kokoro.from_session(session, str(args.model_dir / "voices-v1.0.bin"))
    lines = corpus()
    manifest = AUDIO / "lines.json"
    previous = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else {}
    index = {}
    for name, line in lines.items():
        clip = AUDIO / f"{name}.ogg"
        resource = f"res://{clip.relative_to(PROJECT).as_posix()}"
        if args.force or previous.get(line) != resource or not clip.exists():
            render(engine, line, clip)
            print(name, flush=True)
        index[line] = resource
    assert len(index) == len(lines)
    temporary = manifest.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(manifest)


if __name__ == "__main__":
    main()
