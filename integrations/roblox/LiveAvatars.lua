-- OPTIONAL ONLINE HELPER, excluded from every offline game export.
-- Future integration only: callers must explicitly opt in to account/asset lookups.
local Players = game:GetService("Players")
local Avatars = {}
function Avatars.load(username)
    assert(type(username) == "string" and #username >= 3 and #username <= 20
        and string.match(username, "^[%w_]+$"), "Invalid Roblox username")
    local userId = Players:GetUserIdFromNameAsync(username)
    local model = Players:CreateHumanoidModelFromUserIdAsync(userId)
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Tool") then item:Destroy() end
    end
    return model, userId
end
return Avatars
