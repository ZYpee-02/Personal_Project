// Arithmetic contract for projection checks. This does not implement Roblox rendering.
export const geometry = `
local vector = {}
vector.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
    return vector[key]
end
Vector3 = { new = function(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, vector) end }
Vector2 = { new = function(x, y) return {X=x,Y=y} end }
function vector.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vector.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vector.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function vector.__mul(a,b)
    if type(a)=="number" then a,b=b,a end
    return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
function vector:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function vector:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function vector:Lerp(b,t) return self+(b-self)*t end
local cf = {}; cf.__index = cf
local function frame(p,r,u,b) return setmetatable({Position=p,RightVector=r,UpVector=u,BackVector=b,LookVector=-b},cf) end
CFrame = { new = function(x,y,z)
    return frame(type(x)=="table" and x or Vector3.new(x,y,z),Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1))
end }
function cf:VectorToWorldSpace(v) return self.RightVector*v.X+self.UpVector*v.Y+self.BackVector*v.Z end
function cf:VectorToObjectSpace(v) return Vector3.new(v:Dot(self.RightVector),v:Dot(self.UpVector),v:Dot(self.BackVector)) end
function cf:PointToWorldSpace(v) return self.Position+self:VectorToWorldSpace(v) end
function cf:PointToObjectSpace(v) return self:VectorToObjectSpace(v-self.Position) end
function cf.__mul(a,b)
    return frame(a:PointToWorldSpace(b.Position),a:VectorToWorldSpace(b.RightVector),a:VectorToWorldSpace(b.UpVector),a:VectorToWorldSpace(b.BackVector))
end
function cf:Lerp(b,t)
    return frame(self.Position:Lerp(b.Position,t),self.RightVector:Lerp(b.RightVector,t),self.UpVector:Lerp(b.UpVector,t),self.BackVector:Lerp(b.BackVector,t))
end
function CFrame.fromMatrix(p,r,u,b) return frame(p,r,u,b or r:Cross(u)) end
function CFrame.lookAt(position,target)
    local back = position-target; back = back*(1/back.Magnitude)
    local right = Vector3.new(0,1,0):Cross(back); right = right*(1/right.Magnitude)
    return frame(position,right,back:Cross(right),back)
end
function CFrame.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return frame(Vector3.new(),Vector3.new(cy*cz,cx*sz+sx*sy*cz,sx*sz-cx*sy*cz),
        Vector3.new(-cy*sz,cx*cz-sx*sy*sz,sx*cz+cx*sy*sz),Vector3.new(sy,-sx*cy,cx*cy))
end
UDim = { new = function(scale,offset) return {Scale=scale,Offset=offset} end }
UDim2 = {
    new = function(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end,
    fromOffset = function(x,y) return {X=UDim.new(0,x),Y=UDim.new(0,y)} end,
    fromScale = function(x,y) return {X=UDim.new(x,0),Y=UDim.new(y,0)} end,
}
ColorSequence = { new=function(...) return {...} end }
NumberSequence = { new=function(...) return {...} end }
Color3 = { fromRGB = function(...) return {...} end, fromHSV = function(...) return {...} end }
Enum = setmetatable({RenderPriority={Camera={Value=200},Last={Value=2000}}}, {__index=function(t,key)
    local category=setmetatable({}, {__index=function(_, item) return key.."."..item end}); rawset(t,key,category); return category
end})
`;
