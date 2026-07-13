from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable
from urllib.parse import urlparse


RELEASE_API = "https://api.github.com/repos/anosu/DMM-Mod/releases/latest"
ASSET_NAME = re.compile(r"^Kurusuta-X\.Mod_[0-9.]+_patched\.apk$")
SHA256_DIGEST = re.compile(r"^sha256:([0-9a-fA-F]{64})$")
DOWNLOAD_HOSTS = {
    "github.com",
    "objects.githubusercontent.com",
    "release-assets.githubusercontent.com",
}


@dataclass(frozen=True)
class SourceAsset:
    name: str
    size: int
    sha256: str
    url: str
    release_tag: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download and verify the latest compatible Android APK."
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def require_https_host(url: str, allowed_hosts: set[str]) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in allowed_hosts:
        raise ValueError(f"unsupported download URL: {url}")


def select_source_asset(release: dict[str, Any]) -> SourceAsset:
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise ValueError("GitHub Release does not contain an asset list")
    matches = [asset for asset in assets if ASSET_NAME.fullmatch(str(asset.get("name", "")))]
    if len(matches) != 1:
        raise ValueError(f"expected one standard Kurusuta APK, found {len(matches)}")

    asset = matches[0]
    digest_match = SHA256_DIGEST.fullmatch(str(asset.get("digest", "")))
    if digest_match is None:
        raise ValueError("GitHub Release APK is missing its SHA-256 digest")
    size = asset.get("size")
    if not isinstance(size, int) or size <= 0:
        raise ValueError("GitHub Release APK has an invalid size")
    url = str(asset.get("browser_download_url", ""))
    require_https_host(url, {"github.com"})
    tag = str(release.get("tag_name", ""))
    if not tag:
        raise ValueError("GitHub Release tag is missing")
    return SourceAsset(
        name=str(asset["name"]),
        size=size,
        sha256=digest_match.group(1).lower(),
        url=url,
        release_tag=tag,
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def is_valid_download(path: Path, asset: SourceAsset) -> bool:
    return path.is_file() and path.stat().st_size == asset.size and sha256_file(path) == asset.sha256


def download_asset(
    asset: SourceAsset,
    destination: Path,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if is_valid_download(destination, asset):
        return
    if destination.exists():
        destination.unlink()

    temporary = destination.with_suffix(destination.suffix + ".part")
    offset = temporary.stat().st_size if temporary.is_file() else 0
    if offset >= asset.size:
        temporary.unlink(missing_ok=True)
        offset = 0

    headers = {"User-Agent": "TskSkinSwap-Android/0.2"}
    if offset:
        headers["Range"] = f"bytes={offset}-"
    request = urllib.request.Request(asset.url, headers=headers)
    with opener(request, timeout=60) as response:
        require_https_host(response.geturl(), DOWNLOAD_HOSTS)
        append = offset > 0 and response.status == 206
        if append:
            expected_prefix = f"bytes {offset}-"
            content_range = response.headers.get("Content-Range", "")
            if not content_range.startswith(expected_prefix) or not content_range.endswith(
                f"/{asset.size}"
            ):
                raise ValueError("APK server returned an invalid resume range")
        mode = "ab" if append else "wb"
        with temporary.open(mode) as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)

    if not is_valid_download(temporary, asset):
        raise ValueError("downloaded APK failed its size or SHA-256 check")
    os.replace(temporary, destination)


def fetch_release() -> dict[str, Any]:
    request = urllib.request.Request(
        RELEASE_API,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "TskSkinSwap-Android/0.2",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        require_https_host(response.geturl(), {"api.github.com"})
        return json.load(response)


def main() -> int:
    args = parse_args()
    asset = select_source_asset(fetch_release())
    destination = args.output_dir.resolve() / asset.name
    print(f"Compatible APK: {asset.name} ({asset.release_tag})", file=sys.stderr)
    if not is_valid_download(destination, asset):
        print(f"Downloading {asset.size / 1048576:.1f} MiB...", file=sys.stderr)
    download_asset(asset, destination)
    metadata = {
        "schemaVersion": 1,
        "releaseTag": asset.release_tag,
        "assetName": asset.name,
        "size": asset.size,
        "sha256": asset.sha256,
        "sourceUrl": asset.url,
    }
    metadata_path = args.output_dir.resolve() / "source-apk.json"
    temporary_metadata = metadata_path.with_suffix(".json.tmp")
    temporary_metadata.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    os.replace(temporary_metadata, metadata_path)
    print(destination)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit("Cancelled.")
    except Exception as error:
        raise SystemExit(f"ERROR: {error}")
