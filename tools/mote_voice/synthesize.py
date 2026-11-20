#!/usr/bin/env python3
"""Render one exact Cindertrail subtitle with Kokoro's af_heart model voice."""

import argparse
import sys
import wave
from pathlib import Path

VOICE = "af_heart"
LANGUAGE = "en-us"
SPEED = 1.40
RATE = 24000


def synthesize(input_path: Path, output_path: Path, model_directory: Path) -> None:
    with input_path.open("rb") as caption:
        exact_input = caption.read(4097)
    if not 0 < len(exact_input) <= 4096:
        raise ValueError("Caption out of range.")
    text = exact_input.decode("utf-8")
    if not text.strip():
        raise ValueError("Empty caption.")

    import numpy as np
    import onnxruntime as ort
    from kokoro_onnx import Kokoro

    ort.disable_telemetry_events()
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    options.log_severity_level = 4
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
    session = ort.InferenceSession(
        str(model_directory / "kokoro-v1.0.fp16.onnx"),
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    model = Kokoro.from_session(session, str(model_directory / "voices-v1.0.bin"))
    samples, sample_rate = model.create(text, voice=VOICE, speed=SPEED, lang=LANGUAGE)
    if (sample_rate != RATE or samples.ndim != 1 or not 0 < len(samples) <= 30 * RATE
            or not np.isfinite(samples).all() or not np.any(samples)):
        raise ValueError("Invalid synthesized audio.")
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")

    unfinished = output_path.with_suffix(output_path.suffix + ".part")
    try:
        with wave.open(str(unfinished), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(RATE)
            audio.writeframes(pcm.tobytes())
        unfinished.replace(output_path)
    finally:
        unfinished.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--models", type=Path, required=True)
    args = parser.parse_args()
    try:
        synthesize(args.input, args.output, args.models)
    except Exception:
        print("Mote could not synthesize this caption with the local voice model.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
