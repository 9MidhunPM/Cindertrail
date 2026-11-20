# Valley foley

Kenney recorded and released [RPG Audio](https://kenney.nl/assets/rpg-audio) and [Impact Sounds](https://kenney.nl/assets/impact-sounds) under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The game uses selected layers from these packs for footsteps, cloth, sword swishes and contact, impacts, and shrine hardware.

Recorded flowing water, distant air, and wet footsteps come from [Rubberduck's 100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2), also released under CC0. Their `sfx_100_v2.zip` supplies the source tracks `loop_water_02`, `loop_ambient_01`, `air_01`, and `footstep_wet_01` through `footstep_wet_03`. Cindertrail edits the environment recordings into looped beds and blends the air for distant wind.

With the three original ZIPs in one directory, run `python3 tools/prepare_valley_foley.py /path/to/sources`. This makes four variants per action with trimmed attacks, separate layer gains, a short release taper, and mono 48 kHz PCM output.
