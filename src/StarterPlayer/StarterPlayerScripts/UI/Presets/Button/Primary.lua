--!strict
-- Presets/Button/Primary.lua
-- Baseline "primary action" button theme tokens.

return {
	behaviors = {
	},
	params = {
		buttonKind = "primary",

		btn_bg = Color3.fromRGB(0, 132, 255),
		btn_bg_hover = Color3.fromRGB(15, 142, 255),
		btn_bg_pressed = Color3.fromRGB(0, 118, 230),
		btn_text = Color3.fromRGB(255, 255, 255),

		btn_corner = 8,
		btn_padding = 10,

		btn_hover_tween = 0.08,
		btn_press_tween = 0.05,
	},
}