--!strict

local HttpService = game:GetService("HttpService")

local SchemaMod = require(script.Parent.ParamSchema)

local function hexToColor3(str: string): Color3?
	-- accepts #RRGGBB or #RGB
	if string.sub(str, 1, 1) ~= "#" then
		return nil
	end
	local hex = string.sub(str, 2)
	local function hex2(h)
		return tonumber(h, 16) or 0
	end
	if #hex == 6 then
		return Color3.fromRGB(hex2(hex:sub(1, 2)), hex2(hex:sub(3, 4)), hex2(hex:sub(5, 6)))
	elseif #hex == 3 then
		local r = hex:sub(1, 1)
		local g = hex:sub(2, 2)
		local b = hex:sub(3, 3)
		return Color3.fromRGB(hex2(r .. r), hex2(g .. g), hex2(b .. b))
	end
	return nil
end

local function coerceColor3(v: any): Color3?
	if typeof(v) == "Color3" then
		return v
	end
	if type(v) == "table" and #v == 3 then
		return Color3.fromRGB(tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0)
	end
	if type(v) == "string" then
		local c = hexToColor3(v)
		if c then
			return c
		end
	end
	return nil
end

local function coerceVector2(v: any): Vector2?
	if typeof(v) == "Vector2" then
		return v
	end
	if type(v) == "table" and v.x ~= nil and v.y ~= nil then
		return Vector2.new(tonumber(v.x) or 0, tonumber(v.y) or 0)
	end
	if type(v) == "table" and #v == 2 then
		return Vector2.new(tonumber(v[1]) or 0, tonumber(v[2]) or 0)
	end
	return nil
end

local function coerceUDim2(v: any): UDim2?
	if typeof(v) == "UDim2" then
		return v
	end
	if type(v) == "table" then
		if #v == 4 then
			return UDim2.new(tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0, tonumber(v[4]) or 0)
		end
		if v.x and v.y then
			local xs, xo = 0, 0
			local ys, yo = 0, 0
			if type(v.x) == "table" then
				xs = tonumber(v.x.s or v.x.scale or 0) or 0
				xo = tonumber(v.x.o or v.x.offset or 0) or 0
			end
			if type(v.y) == "table" then
				ys = tonumber(v.y.s or v.y.scale or 0) or 0
				yo = tonumber(v.y.o or v.y.offset or 0) or 0
			end
			return UDim2.new(xs, xo, ys, yo)
		end
	end
	return nil
end

local Coerce = {
	["string"] = function(v)
		return typeof(v) == "string" and v or nil
	end,
	["boolean"] = function(v)
		return typeof(v) == "boolean" and v or nil
	end,
	["number"] = function(v)
		return typeof(v) == "number" and v or nil
	end,
	["Color3"] = coerceColor3,
	["Vector2"] = coerceVector2,
	["UDim2"] = coerceUDim2,
	["table"] = function(v)
		return typeof(v) == "table" and v or nil
	end,
}

local SeenUnknown: { [string]: boolean } = {}

local Params = {}

function Params.decodeJSON(s: any): { [string]: any }
	if typeof(s) ~= "string" or s == "" then
		return {}
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, s)
	return ok and (t :: { [string]: any }) or {}
end

function Params.applySchema(raw: { [string]: any }): { [string]: any }
	local out: { [string]: any } = {}

	local Schema = SchemaMod.getAll()
	for key, spec in pairs(Schema) do
		local v = raw[key]
		local coerced = (Coerce[spec.type] and Coerce[spec.type](v)) or nil
		if coerced then
			out[key] = coerced
		else
			if v then
				if spec.default then
					out[key] = spec.default
				end
				warn(string.format("[UI] Param %s has invalid type; expected %s, got %s.", key, spec.type, typeof(v)))
			else
				out[key] = spec.default
			end
		end
	end

	for key, value in pairs(raw) do
		if not Schema[key] then
			out[key] = value
			if not SeenUnknown[key] then
				SeenUnknown[key] = true
				warn(string.format("[UI] Unknown param key '%s' (not in schema). Keeping as is.", key))
			end
		end
	end

	return out
end

function Params.merge(...)
	local result: { [string]: any } = {}
	for index = 1, select("#", ...) do
		local t = select(index, ...)
		if type(t) == "table" then
			for k, v in pairs(t) do
				result[k] = v
			end
		end
	end

	return result
end

function Params.fromConfigFolder(nodeInstance: Instance): { [string]: any }
	local params: { [string]: any } = {}
	local cfgRoot = nodeInstance:FindFirstChild("Behaviors")
	if not cfgRoot then
		return params
	end

	for _, behaviorFolder in ipairs(cfgRoot:GetChildren()) do
		if behaviorFolder:IsA("Folder") then
			local key = string.lower(behaviorFolder.Name)
			local bucket: { [string]: any } = {}
			for _, value in pairs(behaviorFolder:GetChildren()) do
				if
					value:IsA("StringValue")
					or value:IsA("BoolValue")
					or value:IsA("NumberValue")
					or value:IsA("Vector2Value")
					or value:IsA("Vector3Value")
					or value:IsA("Color3Value")
					or value:IsA("UDim2Value")
				then
					bucket[value.Name] = value.Value
				end
			end
			if next(bucket) then
				params[string.lower(key)] = bucket
			end
		end
	end

	return params
end

function Params.resolve(
	parentParams: { [string]: any? },
	presetParams: { [string]: any? },
	jsonAttr: any,
	nodeInstance: Instance
)
	local jsonParams = Params.decodeJSON(jsonAttr)
	local configParams = Params.fromConfigFolder(nodeInstance)

	local merged = Params.merge(parentParams or {}, presetParams or {})
	return Params.applySchema(merged)
end

return Params
