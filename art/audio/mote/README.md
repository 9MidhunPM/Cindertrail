# Mote voice clips

These clips read Mote's stock guide captions as written. The exact-caption index `lines.json` covers first greetings, nearby shrines, trail directions, each camp landmark, and Vesper's combat cues. The game labels the audio as an AI voice.

The source audio used Kokoro-82M v1.0's `af_heart` voice in American English at 1.4×. Clips are mono 24 kHz Ogg Vorbis. Kokoro-82M uses Apache 2.0. The exporter uses the MIT-licensed Kokoro ONNX wrapper. [Kokoro model card](https://huggingface.co/hexgrad/Kokoro-82M/blob/f3ff3571791e39611d31c381e3a41a3af07b4987/README.md) · [Kokoro ONNX assets](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1)

To regenerate from the current game captions, run the following from the project root using Python with `kokoro-onnx` installed. The model directory needs `kokoro-v1.0.fp16.onnx` and `voices-v1.0.bin`. The encoder needs FFmpeg with libvorbis.

```sh
python art/audio/mote/regenerate.py /path/to/kokoro-models
```
