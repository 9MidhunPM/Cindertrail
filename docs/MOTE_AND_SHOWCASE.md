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

## Runtime checks

- Native Godot 4.7.2 on Wayland and Mobile Vulkan displayed a live Luna response about the actual compass destination. The physical **H** event also produced a separate live response. The exported resource pack contains the guide and excludes `.env`. Mote's optional system speech depends on the installed voice service.
- The two-lap headless showcase finished both runs with 65 shrine-art casts per lap. Each lap kept its core through delivery and the full finale, and the second began with a fresh core. The rendered prologue and chapter transitions were also captured in a native window. The bundled narrator clips produced audio in Godot's mixer with the Dummy driver.
- Headless tests verified each of the seven sunlight draws and independently recovering arts, shrine landmarks, pause and resume advice, and traversal of the extended wave entrances. The farthest validated entrance extension was 3.6 m.
- At 1920×1080, a 32-frame Grove defense sample with four enemies and the HUD averaged 43.9 ms per frame, with a 65.8 ms p95, on Intel ARL integrated graphics. The headless showcase was also running on the machine. The native QA process reported retained objects and resources on exit.
- Exploration keeps the causeway, arch silhouettes and blue-green canopy in view. Compared with the corrected Grove stills, the defensive clearing reads darker, with less turquoise water and less visible cream masonry. The long gold draw stays legible above the lanes in that view.
