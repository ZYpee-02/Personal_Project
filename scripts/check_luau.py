"""Compile all five raw Luau sources and their optional XML place equivalents."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
configured = os.environ.get("LUAU_COMPILE")
compiler = configured or str(ROOT / ".local" / "tools" / "luau-compile")
if not Path(compiler).is_file():
    compiler = shutil.which(configured or "luau-compile")
if not compiler:
    raise SystemExit("Luau compiler missing. Set LUAU_COMPILE to an official luau-compile binary; see README.md.")

targets = sorted((ROOT / "roblox").rglob("*.lua"))
assert len(targets) == 5, "Expected exactly five manual-install game files"
with tempfile.TemporaryDirectory(prefix="riftbound-luau-check-") as directory:
    temp = Path(directory)
    exported = ET.parse(ROOT / "dist" / "RiftboundLive.rbxlx").findall(".//ProtectedString[@name='Source']")
    assert len(exported) == 5, "Missing exported game scripts"
    for index, source in enumerate(exported, 1):
        path = temp / f"exported-place-script-{index}.lua"
        path.write_text(source.text, encoding="utf-8")
        targets.append(path)
    for path in targets:
        result = subprocess.run([compiler, "--null", str(path)], capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(f"Luau compilation FAILED: {path.name}\n{result.stderr}\n{result.stdout}")
        print(f"Luau compiled: {path.name}")
    print(f"All {len(targets)} Luau compilation targets passed (five raw scripts and five XML-exported equivalents).")
