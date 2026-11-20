# Mote and the narrated showcase

Mote follows the traveler in both cameras. Press **H** for advice based on the current objective, defenses, or Vesper's active tell. Critical combat cues and basic guidance work offline.

## Optional OpenAI dialogue

1. Open or create the Git-ignored `.env` beside `project.godot`. For a local native export, put it beside the executable.
2. Set `OPENAI_API_KEY=...` to your OpenAI API key and relaunch Godot. Keep the file local.
3. Mote can now respond to changes on the trail and generate answers when you press **H**. Set `CINDERTRAIL_GUIDE_ONLINE=0` to make online dialogue request-only. Remove the key to run fully offline.
4. Set `CINDERTRAIL_GUIDE_VOICE=1` to read Mote's subtitles aloud through an installed system text-to-speech voice.

The game sends a compact gameplay snapshot to the Responses API. It uses GPT-6 Luna for text. [OpenAI quickstart](https://developers.openai.com/api/docs/quickstart) · [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna)

## Showcase

```sh
./tools/showcase.sh
./tools/showcase.sh --once
```

The default loops in one window. Press **Esc** to exit. Pass `--once` for a single complete journey or `--silent-voice` for captioned narration. The showcase stays offline and uses temporary saves.

It plays the illustrated prologue, walks the valley, defends four shrines, challenges Vesper, and delivers the existing core to the beacon for the full sunrise ending. [Showcase options and verification](../tools/qa/SHOWCASE.md)
