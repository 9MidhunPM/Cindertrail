#!/usr/bin/env python3
"""Record the adaptive score and real gameplay at 1920x1080 without changing player settings."""
import argparse
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Directory for the PCM/video AVI and JSON report")
    parser.add_argument("--wayside-tour", action="store_true", help="Walk the seeded side trails")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(__file__).resolve().parents[2]
    with TemporaryDirectory(prefix="cinder-score-1080-") as folder:
        recording = Path(folder)
        for name in ("project.godot", "default_bus_layout.tres", "art", "data", "scenes", "scripts", "tools", ".godot"):
            source = project / name
            (recording / name).symlink_to(source, target_is_directory=source.is_dir())
        # Movie Maker selects its capture dimensions from project settings before
        # the window receives its requested resolution.
        (recording / "override.cfg").write_text(
            "[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\n"
            "window/size/window_width_override=1920\nwindow/size/window_height_override=1080\n"
        )
        capture = "wayside_tour" if args.wayside_tour else "score_journey"
        environment = dict(os.environ, OPENAI_API_KEY="", CINDERTRAIL_GUIDE_ONLINE="0")
        subprocess.run(
            ["godot", "--path", str(recording), "--resolution", "1920x1080", "--fixed-fps", "24",
             "--disable-vsync", "--write-movie", str(output / f"{capture.replace('_', '-')}.avi"),
             "--script", f"res://tools/qa/{capture}.gd", "--", "--out=" + str(output)],
            check=True, env=environment,
        )


if __name__ == "__main__":
    main()
