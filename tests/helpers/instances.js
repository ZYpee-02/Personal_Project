// Minimal service/Instance contract for orchestration tests, not a Roblox engine.
export const instances = `
local function signal()
    local handlers = {}
    return {
        Connect = function(_, fn)
            local connection = { Connected = true }
            function connection:Disconnect() self.Connected = false end
            handlers[#handlers + 1] = { connection = connection, fn = fn }
            return connection
        end,
        Fire = function(_, ...)
            for _, handler in ipairs(handlers) do
                if handler.connection.Connected then handler.fn(...) end
            end
        end,
    }
end
local methods, nodeMeta = {}, {}
function methods:FindFirstChild(name)
    for _, child in ipairs(self._children) do if child.Name == name then return child end end
end
function methods:WaitForChild(name, timeout)
    assert(type(timeout) == "number" and timeout > 0, "All startup waits must have a timeout")
    return self:FindFirstChild(name)
end
function methods:GetChildren()
    local result = {}; for i, child in ipairs(self._children) do result[i] = child end; return result
end
function methods:IsA(class) return self.ClassName == class end
function methods:GetAttribute(name) return self._attributes[name] end
function methods:GetAttributeChangedSignal(name)
    if not self._attributeSignals[name] then self._attributeSignals[name] = signal() end
    return self._attributeSignals[name]
end
function methods:SetAttribute(name, value)
    if self._attributes[name] ~= value then
        self._attributes[name] = value
        if self._attributeSignals[name] then self._attributeSignals[name]:Fire() end
    end
end
function methods:Destroy() self.Parent = nil; self.Destroyed = true end
function methods:FireAllClients(...) self.OnClientEvent:Fire(...) end
function methods:FireClient(...) end
nodeMeta.__index = function(self, key)
    if methods[key] then return methods[key] end
    if self._properties[key] ~= nil then return self._properties[key] end
    return self:FindFirstChild(key)
end
nodeMeta.__newindex = function(self, key, value)
    if key == "Parent" then
        local old = self._properties.Parent
        if old then
            for i, child in ipairs(old._children) do
                if child == self then table.remove(old._children, i); break end
            end
        end
        if value then table.insert(value._children, self) end
    end
    self._properties[key] = value
end
Instance = { new = function(class)
    local node = setmetatable({ _properties = { ClassName = class, Name = class }, _children = {}, _attributes = {}, _attributeSignals = {} }, nodeMeta)
    if class == "RemoteEvent" then node.OnServerEvent, node.OnClientEvent = signal(), signal() end
    return node
end }
local function instance(class, name, parent)
    local node = Instance.new(class); node.Name, node.Parent = name, parent; return node
end
`;
