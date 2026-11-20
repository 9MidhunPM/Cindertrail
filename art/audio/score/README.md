# Valley score

Scott Buckley composed the six downloadable tracks below and released them under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Cindertrail edits each full mix to a gameplay loop and matches its loudness. The existing Cindertrail piece Last Sunrise plays for the finale.

| Game cue | Track by Scott Buckley | Source filename |
| --- | --- | --- |
| Exploration | [Memories Of Stone](https://www.scottbuckley.com.au/library/memories-of-stone/) | `MemoriesOfStone.mp3` |
| Exploration alternate | [Hiraeth](https://www.scottbuckley.com.au/library/hiraeth/) | `sb_hiraeth.mp3` |
| Defense | [Terminus](https://www.scottbuckley.com.au/library/terminus/) | `sb_terminus.mp3` |
| Defense alternate | [Legionnaire (2022 Remaster)](https://www.scottbuckley.com.au/library/legionnaire-2022/) | `sb_legionnaire2022.mp3` |
| Pursuit | [Hunted](https://www.scottbuckley.com.au/library/hunted/) | `sb_hunted.mp3` |
| Vesper | [Song Of The Forge](https://www.scottbuckley.com.au/library/song-of-the-forge/) | `SongOfTheForge.mp3` |

Download the source tracks to one folder, then run `python3 tools/prepare_valley_score.py /path/to/sources` from the project root with NumPy and FFmpeg installed. The script trims and crossfades each loop, tapers the encoded seam over 12 ms, matches cue levels, and encodes 48 kHz stereo Ogg Vorbis. The target is −18 LUFS integrated with at least 2 dB of true peak headroom per cue.
