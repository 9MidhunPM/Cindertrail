#!/usr/bin/env python3
"""Fetch optional CC0 surface-detail maps using ambientCG's own download metadata.

Default is a metadata-only preview. Add --download to save 1K-JPG maps.
No API keys or dependencies beyond Python 3 are needed.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen
import zipfile

DEFAULT_ASSETS = ["PavingStones036", "Metal032", "Fabric030", "WoodFloor050"]
API = "https://ambientcg.com/api/v2/full_json"
MAX_ARCHIVE_BYTES = 32 * 1024 * 1024
MAX_EXTRACTED_FILE_BYTES = 16 * 1024 * 1024
KEEP_MAPS = {"Color", "Roughness", "NormalGL", "Metalness"}


def fetch(url: str, limit: int) -> bytes:
    if urlparse(url).scheme != "https":
        raise ValueError("Only HTTPS download URLs are supported")
    request = Request(url, headers={"User-Agent": "CindertrailAssetFetch/1.0"})
    with urlopen(request, timeout=45) as response:
        if urlparse(response.geturl()).scheme != "https":
            raise ValueError("Download redirected away from HTTPS")
        payload = response.read(limit + 1)
    if len(payload) > limit:
        raise ValueError(f"Response exceeds {limit} byte limit")
    return payload


def choose_archive(asset: dict) -> dict:
    folders = asset.get("downloadFolders", {})
    for folder in folders.values():
        categories = folder.get("downloadFiletypeCategories", {})
        for category in categories.values():
            for item in category.get("downloads", []):
                if item.get("attribute") == "1K-JPG" and item.get("filetype") == "zip":
                    if item.get("size", 0) > MAX_ARCHIVE_BYTES:
                        raise ValueError("Selected 1K archive exceeds download limit")
                    return item
    raise ValueError(f"No 1K-JPG ZIP listed for {asset.get('assetId')}")


def extract_maps(payload: bytes, destination: Path, asset_id: str) -> list[dict]:
    saved = []
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        for member in archive.infolist():
            name = Path(member.filename).name
            match = re.fullmatch(re.escape(asset_id) + r"_1K-JPG_(\w+)\.(jpg|png)", name)
            if not match or match.group(1) not in KEEP_MAPS:
                continue
            if member.file_size > MAX_EXTRACTED_FILE_BYTES:
                raise ValueError(f"Unexpectedly large map: {name}")
            data = archive.read(member)
            destination.mkdir(parents=True, exist_ok=True)
            path = destination / name  # basename only; no archive paths are trusted
            path.write_bytes(data)
            saved.append({"file": name, "map": match.group(1), "bytes": len(data),
                          "sha256": hashlib.sha256(data).hexdigest()})
    if not saved:
        raise ValueError("Archive did not contain expected 1K OpenGL-compatible maps")
    return saved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset", action="append", help="ambientCG asset ID; may repeat")
    parser.add_argument("--download", action="store_true", help="Download and extract selected maps")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] /
                        "art/textures/third_party/ambientCG")
    args = parser.parse_args()
    ids = args.asset or DEFAULT_ASSETS
    if any(not re.fullmatch(r"[A-Za-z0-9_-]+", i) for i in ids):
        parser.error("Asset IDs must contain only letters, digits, underscore or hyphen")
    metadata_url = API + "?" + urlencode({"id": ",".join(ids), "include": "downloadData",
                                           "limit": len(ids)})
    manifest = {"source": "ambientCG", "license": "CC0-1.0",
                "license_url": "https://docs.ambientcg.com/license/",
                "metadata_url": metadata_url,
                "checked_utc": datetime.now(timezone.utc).isoformat(), "assets": []}
    errors = []
    try:
        metadata = json.loads(fetch(metadata_url, 4 * 1024 * 1024))
        found = {a["assetId"].lower(): a for a in metadata.get("foundAssets", [])}
    except Exception as exc:
        print(f"Could not retrieve official metadata: {exc}", file=sys.stderr)
        return 1
    for requested in ids:
        try:
            asset = found.get(requested.lower())
            if not asset:
                raise ValueError("ID was not found in provider metadata")
            choice = choose_archive(asset)
            source_id = asset["assetId"]
            url = choice["downloadLink"]
            item = {"id": source_id, "name": asset.get("displayName", source_id),
                    "asset_url": asset.get("shortLink", "https://ambientcg.com/a/" + source_id),
                    "download_url": url, "variant": "1K-JPG", "license": "CC0-1.0",
                    "credit": f"{source_id} by ambientCG.com — CC0 1.0 Universal"}
            print(f"{source_id}: {choice.get('size', 0) / 1024**2:.1f} MiB — {url}", flush=True)
            if args.download:
                payload = fetch(url, MAX_ARCHIVE_BYTES)
                item["archive_sha256"] = hashlib.sha256(payload).hexdigest()
                item["maps"] = extract_maps(payload, args.output / source_id, source_id)
                print(f"  Saved {len(item['maps'])} maps", flush=True)
            manifest["assets"].append(item)
        except Exception as exc:
            errors.append({"id": requested, "error": str(exc)})
            print(f"{requested}: {exc}", file=sys.stderr, flush=True)
    if args.download:
        args.output.mkdir(parents=True, exist_ok=True)
        manifest["errors"] = errors
        manifest["complete"] = not errors
        (args.output / "SOURCE_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
        credits = "# Optional surface-detail maps\n\nThese downloaded assets are CC0-1.0.\n\n"
        credits += "\n".join(f"- {a['credit']} — {a['asset_url']}" for a in manifest["assets"])
        credits += "\n\nLicense: https://docs.ambientcg.com/license/\n"
        (args.output / "CREDITS.md").write_text(credits)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
