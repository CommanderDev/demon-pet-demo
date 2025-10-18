local DataStoreService = game:GetService("DataStoreService")

local ServerMod = require(game.ServerScriptService.ServerMod)

local Common = require(game.ReplicatedStorage.Common)
local len = Common.len
local routine = Common.routine
local wait = task.wait

local SaveInfo = require(game.ReplicatedStorage.SaveInfo)

local Store = {}
Store.__index = Store

function Store.new(user)
	local u = {}
	u.user = user
	u.player = user.player

	-- can only do this in studio!
	u.noSave = SaveInfo.NO_SAVE and Common.isStudio

	setmetatable(u, Store)
	return u
end

function Store:init()
	print("STORE SAVE: ", not self.noSave)

	if self.noSave then
		return
	end

	-- untoggle save initially before modules are initialized
	self:toggleSave(false)
	self:initProfile()

	self.initialized = true
end

-- Configuration constants
local CUSTOM_USER = {
	ENABLED = false,

	-- USER_ID = 4362972550, -- karl
	-- USER_ID = 4131861083, -- siben
	USER_ID = 631041340,

	VIEW_ONLY = true,
	EDIT_PROFILE = true,
	LIST_VERSIONS = {
		ENABLED = true,
		MAX_COUNT = 20,
	},
}

function Store:initProfile()
	local user = self.user
	local isDeveloper = Common.checkDeveloper(user.userId)

	-- Determine which user ID to use and profile settings
	local profileSettings = {
		userId = user.userId,
		addUserId = true,
		viewOnly = false,
	}

	-- Override with custom user settings if applicable
	if isDeveloper and CUSTOM_USER.ENABLED and Common.isStudio then
		profileSettings.userId = CUSTOM_USER.USER_ID
		profileSettings.addUserId = false
		profileSettings.viewOnly = CUSTOM_USER.VIEW_ONLY

		print(
			"### TRANSFORMING INTO CUSTOM USER: ",
			Common.getUsernameFromUserId(profileSettings.userId),
			profileSettings.userId
		)
	end

	-- Load the profile
	local profileKey = "Player_" .. profileSettings.userId .. SaveInfo.VERSION
	local profile =
		ServerMod.serverStore:getPlayerProfile(user, profileKey, profileSettings.addUserId, profileSettings.viewOnly)
	self.profile = profile

	-- Handle profile editing in studio if applicable
	if isDeveloper and CUSTOM_USER.ENABLED and CUSTOM_USER.EDIT_PROFILE and Common.isStudio then
		routine(function()
			self:editProfile(profileKey)
		end)
	end
end

function Store:editProfile(profileKey)
	-- Profile version date range configuration
	local profileDateConfig = {
		min = {
			year = 2025,
			month = 3,
			day = 8,
			hour = 12,
			minute = 0,
			second = 0,
			millisecond = 0,
		},
		max = {
			year = 2030,
			month = 3,
			day = 17,
			hour = 12,
			minute = 20,
			second = 0,
			millisecond = 0,
		},
	}

	-- Create DateTime objects from config
	local minDate = DateTime.fromLocalTime(
		profileDateConfig.min.year,
		profileDateConfig.min.month,
		profileDateConfig.min.day,
		profileDateConfig.min.hour,
		profileDateConfig.min.minute,
		profileDateConfig.min.second,
		profileDateConfig.min.millisecond
	)

	local maxDate = DateTime.fromLocalTime(
		profileDateConfig.max.year,
		profileDateConfig.max.month,
		profileDateConfig.max.day,
		profileDateConfig.max.hour,
		profileDateConfig.max.minute,
		profileDateConfig.max.second,
		profileDateConfig.max.millisecond
	)
	local versionQuery = ServerMod.serverStore:getVersionQuery(profileKey, minDate, maxDate)

	if CUSTOM_USER.LIST_VERSIONS.ENABLED then
		self:listProfileVersions(versionQuery)
	else
		self:applyProfileEdits(versionQuery)
	end
end

function Store:listProfileVersions(versionQuery)
	local count = 0
	local delayBetweenVersions = 0.1 -- 0.5

	if not self.profile then
		warn("!!! [DEV] ARE YOU SURE YOU HAVE COMMON.ISSTUDIO BLOCK IN SAVEINFO TURNED OFF?")
		return
	end
	print("GOT ORIG PROFILE: ", self.profile.Data)

	print("LISTING PROFILE VERSIONS...")
	routine(function()
		while count < CUSTOM_USER.LIST_VERSIONS.MAX_COUNT do
			local currProfile = versionQuery:NextAsync()
			if not currProfile then
				print("No more versions found. Total versions listed:", count)
				break
			end

			-- Format and display version information
			local timestamp = self:getProfileTimestamp(currProfile)
			local dateString = Common.getReadableDateString(timestamp)
			local profileData = currProfile.Data

			local crownCount = profileData.ugcManagerInfo.crowns

			print(string.format("Version #%d | Date: %s | Crowns: %d", count, dateString, crownCount))
			print(currProfile.Data)

			wait(delayBetweenVersions)

			count += 1
		end
	end)
end

function Store:getProfileTimestamp(profile)
	if not ServerMod.serverStore.PROFILE_STORE_TOGGLED then
		return profile.MetaData.LastUpdate
	end

	local timestamp
	if profile.KeyInfo and profile.KeyInfo.UpdatedTime then
		-- Convert DateTime to Unix timestamp (seconds)
		timestamp = profile.KeyInfo.UpdatedTime / 1000
	else
		-- Fallback
		timestamp = os.time()
	end

	return timestamp
end

function Store:applyProfileEdits(versionQuery)
	-- Get the first profile from the query
	local targetProfile = versionQuery:NextAsync()
	if not targetProfile then
		warn("No profile versions found in the specified date range")
		return
	end

	-- Create a deep copy to avoid reference issues
	local targetProfileData = Common.deepCopy(targetProfile.Data)
	local profileData = self.profile.Data

	-- Apply specific edits to the current profile
	-- Add more field transfers here as needed
	profileData.ugcManagerInfo = targetProfileData.ugcManagerInfo

	print(
		"Successfully applied profile edits from version dated:",
		Common.getReadableDateString(targetProfile.MetaData.LastUpdate)
	)
end

function Store:get(key)
	if self.noSave then
		return nil
	end

	local profile = self.profile
	if not profile then
		warn(debug.traceback())
		warn("!!! [DEV] NO PROFILE FOUND")
		return nil
	end
	local value = profile.Data[key]

	-- have to deepCopy or sometimes changing the tables can corrupt the values for saving
	local copiedValue = Common.deepCopy(value)
	return copiedValue
end

function Store:toggleSave(newBool)
	self.saveToggled = newBool
end

function Store:checkValueRec(mod, parentList)
	local currType = typeof(mod)

	local newParentList = Common.deepCopy(parentList)
	table.insert(newParentList, mod)

	-- print("CHECKING CURR SAVE MOD: ", mod)
	if not Common.listContains({ "number", "boolean", "table", "string" }, currType) then
		warn("BAD SAVE TYPE: ", currType, newParentList)
		error()
	end

	if typeof(mod) == "table" then
		for k, child in pairs(mod) do
			self:checkValueRec(child, newParentList)
		end
	end
end

function Store:set(key, value)
	if self.noSave then
		return
	end
	if not self.saveToggled then
		return
	end

	local profile = self.profile
	if not profile then
		return
	end
	profile.Data[key] = Common.deepCopy(value)
end

function Store:release()
	local profile = self.profile
	if not profile then
		return
	end

	ServerMod.serverStore:releaseProfile(profile)
end

function Store:cleanDataRec(lst)
	if lst == "none" then
		return nil
	end

	if type(lst) == "table" then
		for k, child in pairs(lst) do
			lst[k] = self:cleanDataRec(child)
		end
	end

	return lst
end

return Store
