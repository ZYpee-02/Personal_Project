-- Offline playtest settings. No network transport or save implementation is bundled.
return {
    HostUserIds = {}, -- Your numeric Roblox user ID(s), required for published host controls.
    PersistenceEnabled = false, -- Must stay false: all game state is in memory.
    BaseMoneyPerSecond = 5,
    VoteMoneyPerSecond = 3,
    WinMoneyPerSecond = 2,
    MaxMoneyPerSecond = 100,
    MaxBalance = 1000000000,
    GatheringSeconds = 55,
    VotingSeconds = 35,
    StormSeconds = 12,
    ResultSeconds = 12,
    MaxCrew = 18,
    MaxQueuedArrivals = 30,
}
