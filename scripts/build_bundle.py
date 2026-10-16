"""Bundle the five raw Luau files, manual instructions and optional Studio place."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
target = ROOT / "dist" / "RiftboundLive-Starter.zip"
with ZipFile(target, "w", ZIP_DEFLATED) as archive:
    for name, source in [
        ("RiftboundLive.rbxlx", "dist/RiftboundLive.rbxlx"),
        ("ServerScriptService/Config.lua", "roblox/ServerScriptService/Config.lua"),
        ("ServerScriptService/RealmState.lua", "roblox/ServerScriptService/RealmState.lua"),
        ("ServerScriptService/World.lua", "roblox/ServerScriptService/World.lua"),
        ("ServerScriptService/Realm.server.lua", "roblox/ServerScriptService/Realm.server.lua"),
        ("StarterPlayerScripts/Realm.client.lua", "roblox/StarterPlayerScripts/Realm.client.lua"),
        ("MANUAL_STUDIO_SETUP.md", "MANUAL_STUDIO_SETUP.md"),
        ("README.md", "README.md"),
        ("docs/BROADCAST_CAMERA_REPLACEMENT.md", "docs/BROADCAST_CAMERA_REPLACEMENT.md"),
        ("docs/BROADCAST_TEST_RESULTS.md", "docs/BROADCAST_TEST_RESULTS.md"),
        ("docs/TOURNAMENT_REGISTRATION_REPLACEMENT.md", "docs/TOURNAMENT_REGISTRATION_REPLACEMENT.md"),
        ("docs/TOURNAMENT_TEST_RESULTS.md", "docs/TOURNAMENT_TEST_RESULTS.md"),
        ("docs/SHARED_SKYWAY_REPLACEMENT.md", "docs/SHARED_SKYWAY_REPLACEMENT.md"),
        ("docs/SHARED_SKYWAY_TEST_RESULTS.md", "docs/SHARED_SKYWAY_TEST_RESULTS.md"),
        ("docs/PLAYTEST.md", "docs/PLAYTEST.md"),
        ("docs/RACE_SHOW_REPLACEMENT.md", "docs/RACE_SHOW_REPLACEMENT.md"),
        ("docs/SPRINT_CONTACT_FIX.md", "docs/SPRINT_CONTACT_FIX.md"),
        ("docs/WINDING_TRAIL_REPLACEMENT.md", "docs/WINDING_TRAIL_REPLACEMENT.md"),
        ("docs/FANTASY_SKYBLOCK_REPLACEMENT.md", "docs/FANTASY_SKYBLOCK_REPLACEMENT.md"),
        ("docs/SKYBRIDGE_ROUTE.svg", "docs/SKYBRIDGE_ROUTE.svg"),
        ("docs/PHASE2_REPLACEMENT.md", "docs/PHASE2_REPLACEMENT.md"),
        ("docs/PRESENTATION_REPLACEMENT.md", "docs/PRESENTATION_REPLACEMENT.md"),
        ("docs/SPRINT_REPLACEMENT.md", "docs/SPRINT_REPLACEMENT.md"),
        ("docs/CAMERA_FIX.md", "docs/CAMERA_FIX.md"),
        ("docs/STARTUP_FIX.md", "docs/STARTUP_FIX.md"),
        ("docs/OFFLINE_SAFETY.md", "docs/OFFLINE_SAFETY.md"),
        ("docs/SOURCE_VALIDATION.md", "docs/SOURCE_VALIDATION.md"),
    ]:
        archive.write(ROOT / source, name)
with ZipFile(target) as archive:
    assert archive.testzip() is None
print(f"Built {target.relative_to(ROOT)} with current offline artifacts and docs.")
