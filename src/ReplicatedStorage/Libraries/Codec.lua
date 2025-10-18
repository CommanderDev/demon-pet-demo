--[[
    Description: Safe serialization for roblox primitives
]]

local Codec = {}

local function packVector3(vector3: Vector3)
	return { _t = "v3", x = vector3.X, y = vector3.Y, z = vector3.Z }
end

local function packVector2(vector3: Vector2)
	return { _t = "v2", x = vector3.X, y = vector3.Y }
end
local function packColor3(color3: Color3)
	return { _t = "c3", r = color3.R, g = color3.G, b = color3.B }
end
local function packCFrame(cframe: CFrame)
	return { _t = "cf", d = { cframe:GetComponents() } }
end
local function packUDim(udim: UDim)
	return { _t = "u", s = udim.Scale, o = udim.Offset }
end
local function packUDim2(udim2: UDim2)
	return { _t = "u2", x = packUDim(udim2.X), y = packUDim(udim2.Y) }
end

local encoders: {} = {
	Vector3 = packVector3,
	Vector2 = packVector2,
	Color3 = packColor3,
	CFrame = packCFrame,
	UDim = packUDim,
	UDim2 = packUDim2,
}

local function unpackVector3(vector3)
	return Vector3.new(vector3.x, vector3.y, vector3.z)
end
local function unpackVector2(vector2)
	return Vector2.new(vector2.x, vector2.y)
end
local function unpackColor3(color3)
	return Color3.new(color3.r, color3.g, color3.b)
end
local function unpackCFrame(cframe)
	return CFrame.new(table.unpack(cframe.d))
end
local function unpackUDim(udim)
	return UDim.new(udim.s, udim.o)
end
local function unpackUDim2(udim2)
	return UDim2.new(unpackUDim(udim2.x), unpackUDim(udim2.y))
end

local decoders: {} = {
	v3 = unpackVector3,
	v2 = unpackVector2,
	c3 = unpackColor3,
	cf = unpackCFrame,
	u = unpackUDim,
	u2 = unpackUDim2,
}

local function isPrimitive(x: any): boolean
	local t = typeof(x)
	return t == "nil" or t == "boolean" or t == "number" or t == "string"
end

function Codec.Encode(value: any): any
	local t = typeof(value)
	if isPrimitive(value) then
		return value
	end
	local encoder = encoders[t]
	if encoder then
		return encoder(value)
	end

	if t == "table" then
		local out = {}
		for k, v in pairs(value) do
			if typeof(v) ~= "Instance" then
				out[k] = Codec.Encode(v)
			end
		end
		return out
	end

	return nil
end

function Codec.Decode(value: any): any
	local t = typeof(value)
	if isPrimitive(value) then
		return value
	end

	if t == "table" and value._t then
		local decoder = decoders[value._t]
		if decoder then
			return decoder(value)
		end
	end

	if t == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[k] = Codec.Decode(v)
		end
		return out
	end

	return value
end

return Codec
