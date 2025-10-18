local SaveInfo = {
	VERSION = "ve.1.001",
	ODS_VERSION = "1.0.3",
	STUDIO_VERSION = "std.ve.0.0.0002",

	-- only enabled in studio!
	NO_SAVE = false,

	-- update this with every update
	GAME_VERSION = "0.0.1",
}

local Common = require(game.ReplicatedStorage.Common)

-- if Common.isStudio then
-- 	SaveInfo.VERSION = SaveInfo.STUDIO_VERSION
-- 	SaveInfo.ODS_VERSION = SaveInfo.ODS_VERSION .. ".STUDIO"
-- end

return SaveInfo
