# Cindertrail homepage

Use Node 24 and run `npm ci && npm run dev` from this directory. `npm run build` writes the homepage to `dist/`. The dev server serves the homepage and gameplay footage. The browser game at `/play/` uses the existing showcase launcher and pinned GitHub release. The Docker image serves the field guide and original showcase at `/showcase/`.

Scroll to unfold the shrine. Drag to orbit it, or focus the model and use the arrow keys. Home resets the view. Vertical swipes keep scrolling the story on touchscreens.

The shrine is derived from the project's authored bronze shrine meshes. The editable Blender file and its build script are in `art/`. Regenerate the animation and four posters with Blender 5.3 and FFmpeg.

```sh
blender -b --factory-startup --python-exit-code 1 -P web/art/build_shrine.py
docker compose -f deploy/web/compose.yaml up --build
```

The Grove and valley backdrops are WebP exports of project concept boards 14 and 11. The gameplay gallery and video use the project's captured footage. See the [asset credits](../CREDITS.md).
