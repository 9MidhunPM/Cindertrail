# Mote's local voice

Mote uses Kokoro-82M v1.0 in English with its `af_heart` voice at 1.40× speed. The model is Apache-2.0 licensed and the ONNX wrapper is MIT licensed. [Model card](https://huggingface.co/hexgrad/Kokoro-82M/blob/f3ff3571791e39611d31c381e3a41a3af07b4987/README.md) · [Kokoro ONNX release](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1)

On Linux, run `tools/mote_voice/setup.sh` once to provision the roughly 192 MB local model files. It uses `uv` and `curl` and checks the two model hashes. An existing Thursday Kokoro installation can supply the same model and Python runtime. For an export, keep this directory at `tools/mote_voice/` beside the executable.

Use `tools/mote_voice/synthesize.sh input.txt output.wav` to render an exact UTF-8 subtitle. A successful job atomically writes 24 kHz mono PCM16. Override the Python and model paths with `CINDERTRAIL_VOICE_PYTHON` and `CINDERTRAIL_VOICE_MODELS` when using an existing environment with a custom layout.
