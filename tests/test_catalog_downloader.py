from __future__ import annotations

import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from catalog_downloader import BundleTarget, download, file_name, write_pc_mapping


class FakeResponse(io.BytesIO):
    def __init__(
        self,
        payload: bytes,
        status: int,
        *,
        url: str = "https://example.invalid/transform.bundle",
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(payload)
        self.status = status
        self.url = url
        self.headers = headers or {}

    def geturl(self) -> str:
        return self.url

    def __enter__(self) -> "FakeResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        self.close()


def target(size: int, catalog_hash: str = "abc123") -> BundleTarget:
    return BundleTarget(
        kind="transform",
        character_id="1001001",
        edition="adult",
        asset_path=(
            "Assets/AssetBundles/GachaCharaAnim/HighQuality/adult/"
            "tf_1001001/tf_1001001_m0_SkeletonData.asset"
        ),
        url="https://example.invalid/transform.bundle",
        size=size,
        catalog_hash=catalog_hash,
        crc=0,
        bundle_name="bundle-name",
    )


class DownloaderTests(unittest.TestCase):
    def test_download_resumes_partial_bundle(self) -> None:
        payload = b"UnityFS" + bytes(range(64))
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "transform.bundle"
            partial = destination.with_suffix(".bundle.part")
            partial.write_bytes(payload[:17])
            requests = []

            def open_request(request, timeout):  # type: ignore[no-untyped-def]
                requests.append((request, timeout))
                return FakeResponse(
                    payload[17:],
                    206,
                    headers={"Content-Range": f"bytes 17-{len(payload) - 1}/{len(payload)}"},
                )

            with patch("catalog_downloader.urllib.request.urlopen", side_effect=open_request):
                download(target(len(payload)), destination)

            self.assertEqual(payload, destination.read_bytes())
            self.assertFalse(partial.exists())
            self.assertEqual("bytes=17-", requests[0][0].headers["Range"])

    def test_failed_download_preserves_existing_destination(self) -> None:
        original = b"previous working bundle"
        invalid = b"invalid payload"
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "transform.bundle"
            destination.write_bytes(original)
            with patch(
                "catalog_downloader.urllib.request.urlopen",
                return_value=FakeResponse(invalid, 200),
            ):
                with self.assertRaises(ValueError):
                    download(target(len(invalid)), destination)

            self.assertEqual(original, destination.read_bytes())
            self.assertTrue(destination.with_suffix(".bundle.part").exists())

    def test_download_rejects_non_https_redirect(self) -> None:
        payload = b"UnityFS" + bytes(range(16))
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "transform.bundle"
            with patch(
                "catalog_downloader.urllib.request.urlopen",
                return_value=FakeResponse(payload, 200, url="http://example.invalid/transform.bundle"),
            ):
                with self.assertRaisesRegex(ValueError, "non-HTTPS"):
                    download(target(len(payload)), destination)

            self.assertFalse(destination.exists())

    def test_download_rejects_wrong_resume_offset(self) -> None:
        payload = b"UnityFS" + bytes(range(32))
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "transform.bundle"
            destination.with_suffix(".bundle.part").write_bytes(payload[:10])
            with patch(
                "catalog_downloader.urllib.request.urlopen",
                return_value=FakeResponse(
                    payload[10:],
                    206,
                    headers={"Content-Range": f"bytes 0-{len(payload) - 11}/{len(payload)}"},
                ),
            ):
                with self.assertRaisesRegex(ValueError, "Content-Range"):
                    download(target(len(payload)), destination)

            self.assertFalse(destination.exists())
            self.assertEqual(payload[:10], destination.with_suffix(".bundle.part").read_bytes())

    def test_pc_mapping_contains_complete_fingerprint(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            game = root / "game"
            bundles = root / "bundles"
            metadata = game / "twinkle_starknightsX_Data/il2cpp_data/Metadata/global-metadata.dat"
            metadata.parent.mkdir(parents=True)
            bundles.mkdir()
            (game / "GameAssembly.dll").write_bytes(b"game-assembly")
            metadata.write_bytes(b"global-metadata")
            item = target(7)
            (bundles / file_name(item)).write_bytes(b"UnityFS")
            mapping_path = root / "staging/mappings.json"

            write_pc_mapping(
                mapping_path,
                game,
                "catalog-sha256",
                "HighQuality",
                "adult",
                [item],
                bundles,
            )

            document = json.loads(mapping_path.read_text(encoding="utf-8"))
            self.assertEqual(2, document["schemaVersion"])
            self.assertEqual("catalog-sha256", document["catalogSha256"])
            self.assertEqual(64, len(document["gameAssemblySha256"]))
            self.assertEqual(64, len(document["globalMetadataSha256"]))
            self.assertEqual(1, len(document["characters"]))
            self.assertEqual(7, document["characters"][0]["transformBundleSize"])


if __name__ == "__main__":
    unittest.main()
