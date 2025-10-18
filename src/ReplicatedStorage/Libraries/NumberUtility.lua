-- NumberUtility
-- Author(s): Jesse Appleton
-- Date: 12/29/2023

--[[
    NumberUtility.FormatWithCommas( number: number ): string
        ( 9999 ) -> "9,999"
    NumberUtility.FormatCurrency( number: number ): string
        ( 999999999 ) -> "999.99M+"
    NumberUtility.NumberToWord( number: number ): string
        ( 107 ) -> "One Hundred Seven"
    NumberUtility.RoundToNearest( number: number, nearest: number ): number
        ( 9.015, 0.01 ) -> 9.02
    NumberUtility.RoundDownToNearest( number: number, nearest: number ): number
        ( 9.015, 0.01 ) -> 9.01
    NumberUtility.FormatSecondsToClockHours( seconds: number ): string -> "hours:minutes"
    NumberUtility.FormatSecondsToHours( seconds: number ): string -> "hours:minutes:seconds"
    NumberUtility.FormatSecondsToTextHours( seconds: number ): string
        ( 3690 ) -> "01h 01m 30s"
    NumberUtility.FormatSecondsToMinutes( seconds: number ): string -> "minutes:seconds"
]]

---------------------------------------------------------------------

-- Constants
local UNDER_TWENTY_WORDS = {
	[0] = "",
	[1] = "One",
	[2] = "Two",
	[3] = "Three",
	[4] = "Four",
	[5] = "Five",
	[6] = "Six",
	[7] = "Seven",
	[8] = "Eight",
	[9] = "Nine",
	[10] = "Ten",
	[11] = "Eleven",
	[12] = "Twelve",
	[13] = "Thirteen",
	[14] = "Fourteen",
	[15] = "Fifteen",
	[16] = "Sixteen",
	[17] = "Seventeen",
	[18] = "Eighteen",
	[19] = "Nineteen",
}
local TEN_WORDS = {
	[1] = "",
	[2] = "Twenty",
	[3] = "Thirty",
	[4] = "Forty",
	[5] = "Fifty",
	[6] = "Sixty",
	[7] = "Seventy",
	[8] = "Eighty",
	[9] = "Ninety",
}
local THOUSAND_WORDS = {
	[0] = "",
	[1] = "Thousand",
	[2] = "Million",
	[3] = "Billion",
	[4] = "Trillion",
}
local MAX_FORMAT_WITH_COMMAS_NUMBER = 1000000000000000 - 1

-- Knit

-- Roblox Services

-- Variables

---------------------------------------------------------------------

local function NumberToStringHelper(number: number): string
	if number == 0 then
		return ""
	elseif number < 20 then
		return UNDER_TWENTY_WORDS[number] .. " "
	elseif number < 100 then
		return TEN_WORDS[math.floor(number / 10)] .. " " .. NumberToStringHelper(number % 10)
	else
		return UNDER_TWENTY_WORDS[math.floor(number / 100)] .. " Hundred " .. NumberToStringHelper(number % 100)
	end
end

local function TrimString(str)
	local clipped
	repeat
		str, clipped = str:gsub("%s$", "")
	until clipped <= 0
	return str
end

local NumberUtility = {}

function NumberUtility.FormatSecondsToMinutes(seconds: number): string
	return string.format("%02.f", math.floor(seconds / 60)) .. ":" .. string.format("%02.f", math.floor(seconds % 60))
end

function NumberUtility.FormatSecondsToTextHours(seconds: number): string
	local seconds = tonumber(seconds)
	if seconds <= 0 then
		return "00h 00m 00s"
	else
		local hours = string.format("%02.f", math.floor(seconds / 3600))
		local minutes = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
		local seconds = string.format("%02.f", math.floor(seconds - (hours * 3600) - (minutes * 60)))
		return tostring(hours) .. "h " .. tostring(minutes) .. "m " .. tostring(seconds) .. "s"
	end
end

function NumberUtility.FormatSecondsToHours(seconds: number): string
	local seconds = tonumber(seconds)
	if seconds <= 0 then
		return "00:00:00"
	else
		local hours = string.format("%02.f", math.floor(seconds / 3600))
		local minutes = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
		local seconds = string.format("%02.f", math.floor(seconds - (hours * 3600) - (minutes * 60)))
		return tostring(hours) .. ":" .. tostring(minutes) .. ":" .. tostring(seconds)
	end
end

function NumberUtility.FormatSecondsToClockHours(seconds: number): string
	local seconds = tonumber(seconds)
	if seconds <= 0 then
		return "00:00"
	else
		local hours = string.format("%02.f", math.floor(seconds / 3600))
		local minutes = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
		return tostring(hours) .. ":" .. tostring(minutes)
	end
end

function NumberUtility.FormatWithCommas(number: number): string
	local formatted, k = number, nil
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

-- TODO: Turn this into a maxFloat, suffix for loop
function NumberUtility.FormatCurrency(number: number): string
	number = math.clamp(number, 0, MAX_FORMAT_WITH_COMMAS_NUMBER)
	local suffix
	if number < 1000000 then
		---999,999
		return NumberUtility.FormatWithCommas(number)
	elseif number < 1000000 then
		--99.99K+
		suffix = "K+"
		number = number / 1000
	elseif number < 1000000000 then
		--999.99M+
		suffix = "M+"
		number = number / 1000000
	elseif number < 1000000000000 then
		--999.99B+
		suffix = "B+"
		number = number / 1000000000
	elseif number < 1000000000000000 then
		--999.99T+
		suffix = "T+"
		number = number / 1000000000000
	end
	return (string.format("%.2f", NumberUtility.RoundDownToNearest(number, 0.01)) .. suffix) or ""
end

function NumberUtility.RoundToNearest(float: number, nearest: number?): number
	return math.floor(float / nearest + 0.5) * nearest
end

function NumberUtility.RoundDownToNearest(float: number, nearest: number?): number
	return math.floor(float / nearest) * nearest
end

function NumberUtility.NumberToWord(number: number): string
	local number = math.floor(number)
	if number == 0 then
		return "Zero"
	end
	local thousandIteration = 0
	local wordString = ""
	while number > 0 do
		if number % 1000 ~= 0 then
			wordString = NumberToStringHelper(number % 1000) .. THOUSAND_WORDS[thousandIteration] .. " " .. wordString
		end
		number = math.floor(number / 1000)
		thousandIteration = thousandIteration + 1
	end
	return TrimString(wordString)
end

return NumberUtility
