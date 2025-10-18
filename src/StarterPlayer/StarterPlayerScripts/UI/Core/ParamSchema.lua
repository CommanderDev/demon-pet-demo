--!strict

export type Spec = {
	type: string,
	default: any?,
	desc: string?, -- For dianostics
}

local Schema: { [string]: Spec } = {
	theme = { type = "string", default = "dark", desc = "Theme token or name" },
	hoverBg = { type = "Color3", default = nil, desc = "Hover background color" },
	delegatedInput = { type = "boolean", default = false, desc = "Centralized input handling for dense UI" },

	-- Animation presets
	appear = { type = "string", default = nil, desc = "AnimateIn preset (pop|fade|slideRight, etc" },
	appearDuration = { type = "number", default = 0.18, desc = "Time for appear animation" },
	appearOffset = { type = "number", default = 24, desc = "px offset for slide animations" },
	easingStyle = { type = "string", default = "Quad", desc = "Quad|Sine|Cubic|Back|Linear" },
	easingDirection = { type = "string", default = "Out", desc = "Out|In|InOut" },
	-- Tooltip behavior
	tooltip = { type = "table", default = nil, desc = "{ text: string, delay: number" },

	-- HoverClose behavior
	hoverCloseAlwaysVisible = { type = "boolean", default = false, desc = "Show × even when not hovered" },
	hoverClosePadding = { type = "number", default = 8, desc = "px from top-right" },
	hoverCloseSize = { type = "number", default = 20, desc = "× button size (px)" },
	hoverCloseZBias = { type = "number", default = 2, desc = "× ZIndex relative to node" },

	-- Button.Primary theme tokens
	buttonKind = { type = "string", default = "primary" },
	btn_bg = { type = "Color3", default = Color3.fromRGB(0, 132, 255) },
	btn_bg_hover = { type = "Color3", default = Color3.fromRGB(15, 142, 255) },
	btn_bg_pressed = { type = "Color3", default = Color3.fromRGB(0, 118, 230) },
	btn_text = { type = "Color3", default = Color3.fromRGB(255, 255, 255) },
	btn_corner = { type = "number", default = 8 },
	btn_padding = { type = "number", default = 10 },
	btn_hover_tween = { type = "number", default = 0.08 },
	btn_press_tween = { type = "number", default = 0.05 },
}

local ParamSchema = {}

function ParamSchema.getAll(): { [string]: Spec }
	return Schema
end

-- Safely allow behaviors/policies/presets to add key safely
function ParamSchema.register(key: string, spec: Spec): ()
	if Schema[key] then
		warn(string.format("[UI]ParamSchema: key '%s' already registered", key))
	end

	Schema[key] = spec
end

return ParamSchema
