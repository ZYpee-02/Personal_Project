-- Simulated LIVE events; optional Roblox appearance loading only. No TikTok or saves.
return {
    HostUserIds = {}, -- Your numeric Roblox user ID(s), required for published host controls.
    PersistenceEnabled = false, -- Must stay false: all game state is in memory.
    BaseMoneyPerSecond = 5,
    VoteMoneyPerSecond = 3,
    WinMoneyPerSecond = 2,
    MaxMoneyPerSecond = 100,
    MaxBalance = 1000000000,
    AutoActivities = true,
    AutoJoinPlayers = false, -- host is a spectator; JOIN tools still enqueue any username.
    SprintOnly = true, -- false restores Starfall/Sprint/Relay rotation. Sprint is always physical.
    SprintCompetitors = 5,
    SprintRaceSeconds = 80,
    SprintFinishBonus = 40,
    LoadAvatarAppearances = true, -- false = strictly local fallback rigs, no account requests.
    AppearanceTimeoutSeconds = 8,
    DemoAppearanceUserIds = { 1, 156, 261, 2, 3 }, -- cosmetic accounts, not LIVE viewers.
    ActivityMoneyPerSecond = 2,
    RoundWinMoneyPerSecond = 1,
    CoinsPerPoint = 2,
    RoundPrizes = { 120, 75, 40 },
    GatheringSeconds = 12,
    VotingSeconds = 8,
    StormSeconds = 30, -- The automatic competition plays during this phase.
    ResultSeconds = 10,
    MaxCrew = 18,
    MaxQueuedArrivals = 30,
    OfflineDemoEnabled = true,
    DemoStudioOnly = true, -- Never imply the seeded crew are real LIVE viewers.
    DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion" },
    AutoSimulateGifts = true,
    DemoGiftSeconds = 18,
    SceneUpdatesPerSecond = 12, -- Bound server-side procedural animation replication.
    SnapshotSeconds = 0.5,
    StreamCameraDefault = true,
}
