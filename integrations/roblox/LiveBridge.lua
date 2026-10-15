-- OPTIONAL ONLINE MODULE. Not included in the offline installer or place.
local HttpService = game:GetService("HttpService")
local Bridge = {}
function Bridge.start(Config, enqueue)
local processed, processedOrder = {}, {}
local status = "connecting"
local function request(path, method, body)
    local result = HttpService:RequestAsync({
        Url = Config.BridgeUrl .. path,
        Method = method,
        Headers = { ["Authorization"] = "Bearer " .. Config.BridgeToken, ["Content-Type"] = "application/json" },
        Body = body and HttpService:JSONEncode(body) or nil,
    })
    if not result.Success then error("Bridge HTTP " .. tostring(result.StatusCode)) end
    return HttpService:JSONDecode(result.Body)
end

task.spawn(function()
        if not string.match(Config.BridgeUrl, "^https://") or #Config.BridgeToken < 24 then
            status = "configuration required"
            warn("Use an HTTPS BridgeUrl and a private game token of at least 24 characters.")
            return
        end
        local backoff = Config.BridgePollSeconds
        local warned = false
        while true do
            local ok = pcall(function()
                local batch = request("/api/game/events", "GET")
                if type(batch.events) ~= "table" or #batch.events > 20 then error("Invalid bridge response") end
                local results = {}
                for _, event in ipairs(batch.events) do
                    if type(event.id) ~= "string" then error("Invalid event ID") end
                    if not processed[event.id] then
                        local completed, receipt = false, nil
                        local queued = enqueue(event, function(applied, message)
                            receipt = { id = event.id, status = applied and "applied" or "rejected", message = string.sub(message, 1, 240) }
                            completed = true
                        end)
                        if not queued then break end -- Backpressure: leave the event pending.
                        while not completed do task.wait(0.1) end
                        processed[event.id] = receipt
                        table.insert(processedOrder, event.id)
                        -- More than the bridge's maximum pending queue, with a bounded memory cost.
                        if #processedOrder > 500 then processed[table.remove(processedOrder, 1)] = nil end
                    end
                    table.insert(results, processed[event.id])
                end
                if #results > 0 then request("/api/game/ack", "POST", { results = results }) end
            end)
            if ok then
                status, backoff, warned = "connected", Config.BridgePollSeconds, false
            else
                status = "disconnected · retrying"
                if not warned then warn("Riftbound bridge unavailable. Check HTTPS, HTTP Requests, and the game token."); warned = true end
                backoff = math.min(30, math.max(3, backoff * 2))
            end
            task.wait(backoff)
        end
    end)
return function() return status end
end
return Bridge
