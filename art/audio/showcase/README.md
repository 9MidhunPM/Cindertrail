# Showcase narrator

These ten original English lines are the spoken versions of the captions in `tools/qa/showcase.gd`. They play only in the showcase and the source clips are stored as mono 24 kHz Ogg Vorbis.

The clips were synthesized locally on 2026-11-21 with Kokoro-82M v1.0, the bundled `bm_george` voice, British English (`en-gb`), and speed 1.04. Kokoro-82M is distributed under Apache 2.0. The exporter used the MIT-licensed `kokoro-onnx` wrapper and the FP16 model bundle. [Model card](https://huggingface.co/hexgrad/Kokoro-82M/blob/f3ff3571791e39611d31c381e3a41a3af07b4987/README.md), [ONNX assets](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1).

To regenerate a line, synthesize its caption as a mono 24 kHz PCM WAV and encode it with FFmpeg using `highpass=f=65,acompressor=threshold=0.1:ratio=2:attack=15:release=100,alimiter=limit=0.85:level=false` and `-c:a libvorbis -q:a 5`.
