"""Explicit, audited source manifest for both offline Roblox exports."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ("ServerScriptService", "ModuleScript", "Config", "Config.lua"),
    ("ServerScriptService", "Script", "Realm", "Realm.server.lua"),
    ("ServerScriptService", "ModuleScript", "RealmState", "RealmState.lua"),
    ("ServerScriptService", "ModuleScript", "World", "World.lua"),
    ("StarterPlayerScripts", "LocalScript", "Realm", "Realm.client.lua"),
]
ALLOWED_SERVICES = {
    "RunService", "ServerScriptService", "StarterPlayer", "Players",
    "ReplicatedStorage", "Lighting", "TweenService",
}
FORBIDDEN = re.compile(
    r"\b(?:DataStoreService|MemoryStoreService|HttpService|InsertService|AssetService|"
    r"MessagingService|TeleportService|MarketplaceService|loadstring|LoadAsset|"
    r"RequestAsync|GetAsync|PostAsync|SetAsync|UpdateAsync|RemoveAsync|"
    r"GetUserIdFromNameAsync|CreateHumanoidModelFromUserIdAsync|GetHumanoidDescriptionFromUserId)\b"
    r"|https?://|rbxassetid://|rbxasset://",
    re.IGNORECASE,
)


def audit(text, label):
    stream_calls = re.findall(r"\w+:RequestStreamAroundAsync\s*\(", text)
    if stream_calls and (not str(label).endswith("Realm.client.lua") or len(stream_calls) != 1
                         or "workspace.StreamingEnabled and missingGeometry" not in text
                         or "streamRequests < 3" not in text
                         or "player:RequestStreamAroundAsync(requestFocus, 5)" not in text):
        raise ValueError("Native geometry streaming is allowed only in the bounded spectator client")
    avatar_calls = re.findall(r"(\w+):((?:GetHumanoidDescriptionFromUserIdAsync|CreateHumanoidModelFromDescriptionAsync))\s*\(", text)
    if avatar_calls and (not str(label).endswith("World.lua") or "settings.LoadAvatarAppearances ~= true" not in text):
        raise ValueError("Appearance APIs are allowed only in the guarded World loader")

    match = FORBIDDEN.search(text)
    if match:
        raise ValueError(f"Offline export refused: {label} contains {match.group(0)!r}")
    for service in re.findall(r'GetService\s*\(\s*[\"\']([^\"\']+)[\"\']\s*\)', text):
        if service not in ALLOWED_SERVICES:
            raise ValueError(f"Offline export refused: unexpected service {service!r}")
    for dependency in re.findall(r'\brequire\s*\(([^)]+)\)', text):
        if dependency.strip() not in {"script.Parent.Config", "script.Parent.RealmState", "script.Parent.World"}:
            raise ValueError(f"Offline export refused: unexpected require in {label}")


def sources():
    result = []
    for directory, kind, name, filename in FILES:
        path = ROOT / "roblox" / directory / filename
        source = path.read_text(encoding="utf-8")
        audit(source, str(path.relative_to(ROOT)))
        result.append((directory, kind, name, source))
    return result
