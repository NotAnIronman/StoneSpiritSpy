"""Build the plugin ZIP and verify its contents."""
from hashlib import sha256
import json
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "plugin.json").read_text(encoding="utf-8"))
files = [root / "main.lua", root / "plugin.json", root / "README.md"]
files += sorted((root / "lib").rglob("*.lua"))
output = root / "releases" / f"StoneSpiritSpy-{manifest['version']}.zip"
output.parent.mkdir(exist_ok=True)

with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
    for path in files:
        entry = ZipInfo(path.relative_to(root).as_posix(), date_time=(2026, 10, 25, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o644 << 16
        archive.writestr(entry, path.read_bytes())

with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {path.relative_to(root).as_posix() for path in files}
    for path in files:
        assert archive.read(path.relative_to(root).as_posix()) == path.read_bytes()

print(f"Verified {len(files)} source files: {output}")
print(f"SHA256 {sha256(output.read_bytes()).hexdigest()}")
