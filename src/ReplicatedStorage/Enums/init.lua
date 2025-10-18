local CustomEnum = require(game.ReplicatedStorage.Libraries.CustomEnum)

local Enums = {}

for _, enumInfo in ipairs(script:GetChildren()) do
	local def = require(enumInfo)

	local enumType = CustomEnum.create(enumInfo.Name, def, {
		startAt = 1,
		freeze = true,
	})

	Enums[enumInfo.Name] = enumType
end

return Enums
