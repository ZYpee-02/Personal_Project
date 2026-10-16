import { instances } from './instances.js';
import { geometry } from './geometry.js';

// Deliberately limited UI/service mocks. Layout is arithmetic, not font rasterization.
export const presentationEngine = instances + geometry + `
local now, delays, actions, spawnedJobs = 0, {}, {}, {}
os.clock = function() return now end
task = { spawn=function(fn) spawnedJobs[#spawnedJobs+1]=fn end, delay=function(seconds,fn) delays[#delays+1]={seconds,fn} end, wait=function(seconds) now=now+(seconds or 0.03) end }
warn = function(message) error(message) end
local viewport = Vector2.new(390,844)
function methods:GetDescendants()
    local result={}
    for _,child in ipairs(self:GetChildren()) do
        result[#result+1]=child
        for _,descendant in ipairs(child:GetDescendants()) do result[#result+1]=descendant end
    end
    return result
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self:GetChildren()) do if child:IsA(class) then return child end end
end
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation")) end
function methods:GetPropertyChangedSignal(name) return self:GetAttributeChangedSignal("property:"..name) end
function methods:FireServer(...) actions[#actions+1]={...} end
function methods:GetPivot() return (self.PrimaryPart and self.PrimaryPart.CFrame) or self._properties.Pivot or CFrame.new() end
function methods:PivotTo(value)
    local delta=value.Position-self:GetPivot().Position
    for _,part in ipairs(self:GetDescendants()) do
        if part:IsA("BasePart") then part.CFrame=frame(part.Position+delta,part.CFrame.RightVector,part.CFrame.UpVector,part.CFrame.BackVector) end
    end
    self.Pivot=value
end
function methods:ScaleTo(value) self.AppliedScale=value end
function methods:MoveTo(value) self.MoveGoal=value end
function methods:SetNetworkOwner(value) self.ServerOwned=value==nil end
local function uiRect(node)
    if not node or node.ClassName=="PlayerGui" then return {x=0,y=0,w=viewport.X,h=viewport.Y},1 end
    local parent,scale=uiRect(node.Parent)
    if node.ClassName=="ScreenGui" then return parent,scale end
    local ownScale=1
    for _,child in ipairs(node:GetChildren()) do if child.ClassName=="UIScale" then ownScale=child.Scale or 1 end end
    local size=node.Size or UDim2.fromOffset(0,0)
    local pos=node.Position or UDim2.fromOffset(0,0)
    local anchor=node.AnchorPoint or Vector2.new(0,0)
    local w=(parent.w*size.X.Scale+size.X.Offset*scale)*ownScale
    local h=(parent.h*size.Y.Scale+size.Y.Offset*scale)*ownScale
    return {x=parent.x+parent.w*pos.X.Scale+pos.X.Offset*scale-w*anchor.X,
        y=parent.y+parent.h*pos.Y.Scale+pos.Y.Offset*scale-h*anchor.Y,w=w,h=h},scale*ownScale
end
local originalIndex=nodeMeta.__index
nodeMeta.__index=function(self,key)
    if key=="AbsolutePosition" then local r=uiRect(self); return Vector2.new(r.x,r.y) end
    if key=="AbsoluteSize" then local r=uiRect(self); return Vector2.new(r.w,r.h) end
    if key=="Position" and self:IsA("BasePart") then return self.CFrame.Position end
    return originalIndex(self,key)
end
local originalNew=Instance.new
Instance.new=function(class)
    local node=originalNew(class)
    if class=="Frame" or class=="TextLabel" or class=="TextButton" or class=="TextBox" then node.Visible=true end
    if class=="ScreenGui" or class=="BillboardGui" then node.Enabled=true end
    if class=="BillboardGui" then node.StudsOffset, node.StudsOffsetWorldSpace=Vector3.new(),Vector3.new() end
    if class=="TextButton" then node.Activated=signal() end
    if class=="Humanoid" then node.Health=100; node.FloorMaterial=Enum.Material.Slate end
    if class=="Part" or class=="SpawnLocation" then node.CFrame=CFrame.new(); node.Size=Vector3.new(4,1.2,2) end
    return node
end
workspace=instance("Workspace","Workspace")
workspace.DescendantAdded,workspace.DescendantRemoving=signal(),signal()
local originalNewIndex=nodeMeta.__newindex
nodeMeta.__newindex=function(self,key,value)
    originalNewIndex(self,key,value)
    if key=="Parent" and value then
        local ancestor=value
        while ancestor do
            if ancestor==workspace then
                workspace.DescendantAdded:Fire(self)
                for _,child in ipairs(self:GetDescendants()) do workspace.DescendantAdded:Fire(child) end
                break
            end
            ancestor=ancestor.Parent
        end
    end
end
local camera=instance("Camera","Camera",workspace)
camera.CFrame,camera.ViewportSize,camera.FieldOfView,camera.CameraType=CFrame.new(0,100,180),viewport,70,Enum.CameraType.Custom
camera.FieldOfViewMode=Enum.FieldOfViewMode.Vertical
workspace.CurrentCamera=camera
function methods:WorldToViewportPoint(point)
    local localPoint=self.CFrame:PointToObjectSpace(point)
    local depth=-localPoint.Z
    local tanV=math.tan(math.rad(self.FieldOfView)/2)
    local x=viewport.X/2+localPoint.X*viewport.Y/(2*tanV*depth)
    local y=viewport.Y/2-localPoint.Y*viewport.Y/(2*tanV*depth)
    return Vector3.new(x,y,depth),depth>0 and x>=0 and x<=viewport.X and y>=0 and y<=viewport.Y
end
local storage=instance("ReplicatedStorage","ReplicatedStorage")
local remotes=instance("Folder","Riftbound",storage)
remotes:SetAttribute("Ready",true)
remotes:SetAttribute("StartupState","ready")
for _,name in ipairs({"Snapshot","Action","Notice"}) do instance("RemoteEvent",name,remotes) end
local player=instance("Player","Tester")
player:SetAttribute("RiftboundHost",true)
local playerGui=instance("PlayerGui","PlayerGui",player)
local players={LocalPlayer=player}
local renderStep
local runtime={BindToRenderStep=function(_,name,priority,fn) renderStep=fn end}
local lighting=instance("Lighting","Lighting")
local tweenService={Create=function(_,object,info,goal)
    return {Play=function(self) self.Played=true end,Cancel=function(self) self.Cancelled=true end,Goal=goal}
end}
TweenInfo={new=function(seconds) return {Time=seconds} end}
Random={new=function() return {NextNumber=function(_,low,high) return (low+high)/2 end} end}
game={GetService=function(_,name)
    if name=="Players" then return players end
    if name=="ReplicatedStorage" then return storage end
    if name=="RunService" then return runtime end
    if name=="Lighting" then return lighting end
    if name=="TweenService" then return tweenService end
    error("Unexpected service "..name)
end}
local function setViewport(w,h)
    viewport=Vector2.new(w,h); camera.ViewportSize=viewport
    camera:GetPropertyChangedSignal("ViewportSize"):Fire()
end
`;
