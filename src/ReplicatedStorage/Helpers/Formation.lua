-- API:
--   local Formation = require(...Formation)
--   local slots, map = Formation.Compute(leaderPos, leaderFwd, members, opts)
--
-- Where:
--   leaderPos : Vector3
--   leaderFwd : Vector3 (will be flattened to XZ plane)
--   members   : array of "units" OR demon controllers; each must expose a stable .id string
--               (if you pass demon controllers, module reads demon.unit.id)
--   opts      : {
--     type        = FormationType.X (enum id) or string "Wedge"|"Line"|"Circle"|"Column"|"Square",
--     spacing     = number (studs between neighbors)   [default 5]
--     faceLeader  = boolean (slots face same dir as leader) [default true]
--     ringRadius  = number (only for Circle)           [auto if nil]
--     rows        = number (only for Square/Column)    [auto if nil]
--     cols        = number (only for Square)           [auto if nil]
--   }
--
-- Returns:
--   slots : array of Vector3 in the SAME order as `members`
--   map   : { [unitId] = Vector3 } for quick lookup
--
-- Notes:
-- - Stable order: we don't sort your members unless you ask; we keep given order so party stable-indexing works.
-- - If you need stable order across joins/leaves, give `members` already sorted by a stable key (e.g., unit.id).
-- - All math is on the XZ plane (Y from leaderPos is preserved).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(game.ReplicatedStorage.Enums)

local Formation = {}

local function flatten(v: Vector3): Vector3
	-- Remove Y component, keep horizontal
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 1e-5 then
		return Vector3.new(0, 0, -1)
	end
	return h.Unit
end

local function orthoRight(fwd: Vector3): Vector3
	-- Right vector on XZ plane
	local f = flatten(fwd)
	local r = Vector3.new(-f.Z, 0, f.X) -- rotate +90° on XZ
	return r.Unit
end

local function resolveUnitId(m)
	-- Accept unit table or demon controller
	if type(m) ~= "table" then
		return nil
	end
	if m.id then
		return m.id
	end
	if m.unit and m.unit.id then
		return m.unit.id
	end
	return nil
end

-- ===== Pattern solvers =====

local function solveLine(leaderPos, fwd, n, s)
	-- Single file behind the leader, spaced along -fwd
	local out = table.create(n)
	for i = 1, n do
		out[i] = leaderPos + (-fwd * (i * s))
	end
	return out
end

local function solveColumn(leaderPos, fwd, right, n, s, rowsHint)
	-- Two files (left/right) trailing the leader
	local out = table.create(n)
	local row = 1
	local side = -1 -- start left of leader
	for i = 1, n do
		local lateral = right * side * s * 0.9
		local back = -fwd * (row * s)
		out[i] = leaderPos + back + lateral
		side = -side
		if side < 0 then
			row += 1
		end
	end
	return out
end

local function solveWedge(leaderPos, fwd, right, n, s)
	-- Triangular wedge: each row can hold progressively more (1, 2, 3, 4, ...)
	-- Demons in partially-filled rows are centered
	local out = table.create(n)
	local idx = 1
	local row = 1

	while idx <= n do
		-- Row capacity grows: row 1 = 1, row 2 = 2, row 3 = 3, etc.
		local rowCapacity = row

		-- How many demons actually go in this row?
		local demonsInRow = math.min(rowCapacity, n - idx + 1)

		-- Center demons within the row
		local startCol = -(demonsInRow - 1) / 2

		for col = 0, demonsInRow - 1 do
			if idx > n then
				break
			end

			local back = -fwd * (row * s)
			local lateral = right * (startCol + col) * s * 0.6
			out[idx] = leaderPos + back + lateral
			idx += 1
		end

		row += 1
	end

	return out
end

local function solveCircle(leaderPos, fwd, n, s, ringRadius)
	-- Place evenly on a ring around the leader
	local out = table.create(n)
	if n == 1 then
		out[1] = leaderPos - fwd * s
		return out
	end
	local radius = ringRadius
	if not radius then
		-- heuristic: radius grows with n; ~s * (1 + 0.5*(n/6))
		radius = s * (1 + 0.5 * (n / 6))
	end
	-- Angle zero aligned with -fwd so first slot is behind leader
	local baseDir = (-flatten(fwd))
	local baseRight = orthoRight(baseDir)
	for i = 1, n do
		local t = (i - 1) / n
		local angle = t * math.pi * 2
		-- rotate baseDir around Y
		local dir = (baseDir * math.cos(angle)) + (baseRight * math.sin(angle))
		out[i] = leaderPos + dir.Unit * radius
	end
	return out
end

local function solveSquare(leaderPos, fwd, right, n, s, rowsHint, colsHint)
	-- Grid block behind the leader (rows x cols), row-major fill
	local out = table.create(n)
	local cols = colsHint or math.ceil(math.sqrt(n))
	local rows = rowsHint or math.ceil(n / cols)
	local idx = 1
	for r = 1, rows do
		for c = 1, cols do
			if idx > n then
				break
			end
			local x = (c - ((cols + 1) / 2)) * (s * 0.9)
			local z = r * s
			out[idx] = leaderPos + (-fwd * z) + (right * x)
			idx += 1
		end
	end
	return out
end

-- ===== Public API =====

function Formation.compute(leaderPos: Vector3, leaderFwd: Vector3, members: { any }, opts: table)
	opts = opts or {}
	local n = #members
	if n == 0 then
		return {}, {}
	end

	local fwd = flatten(leaderFwd)
	local right = orthoRight(fwd)
	local spacing = tonumber(opts.spacing) or 5

	-- Accept either enum id or string
	local tIdOrName = opts.type
	local typeName: string
	if typeof(tIdOrName) == "number" then
		typeName = Enums.FormationType:nameOf(tIdOrName)
	else
		typeName = tostring(tIdOrName or "Wedge")
	end

	local slots
	if typeName == "Line" then
		slots = solveLine(leaderPos, fwd, n, spacing)
	elseif typeName == "Column" then
		slots = solveColumn(leaderPos, fwd, right, n, spacing, opts.rows)
	elseif typeName == "Circle" then
		slots = solveCircle(leaderPos, fwd, n, spacing, opts.ringRadius)
	elseif typeName == "Square" then
		slots = solveSquare(leaderPos, fwd, right, n, spacing, opts.rows, opts.cols)
	else
		-- default wedge
		slots = solveWedge(leaderPos, fwd, right, n, spacing)
	end

	local map = {}
	for i, m in ipairs(members) do
		local id = resolveUnitId(m)
		if id then
			map[id] = slots[i]
		end
	end

	if opts.faceLeader == false then
		-- leave as-is; demons will set facing from their movement
	else
		-- No-op here; facing is implicit via leader fwd/right; consumers can read fwd if they need CFrames
	end

	return slots, map
end

-- Convenience that returns slot CFrames (look-at using leader forward)
function Formation.computeCFrames(leaderPos: Vector3, leaderFwd: Vector3, members: { any }, opts: table)
	local slots, map = Formation.Compute(leaderPos, leaderFwd, members, opts)
	local fwd = flatten(leaderFwd)
	local cfSlots = table.create(#slots)
	for i, p in ipairs(slots) do
		cfSlots[i] = CFrame.lookAt(p, p + fwd)
	end
	local cfMap = {}
	for i, m in ipairs(members) do
		local id = resolveUnitId(m)
		if id then
			cfMap[id] = cfSlots[i]
		end
	end
	return cfSlots, cfMap
end

-- Helper function to compute a single slot's offset in local space
-- Given a slot index and total member count, returns the local-space offset
function Formation.computeSlotOffset(slotIndex: number, memberCount: number, opts: table): Vector3
	opts = opts or {}
	if memberCount == 0 or slotIndex < 1 or slotIndex > memberCount then
		return Vector3.zero
	end

	-- Create dummy members array (we only need the count)
	local dummyMembers = table.create(memberCount)
	for i = 1, memberCount do
		dummyMembers[i] = { id = tostring(i) }
	end

	-- Compute slots at origin facing forward
	local origin = Vector3.zero
	local forward = Vector3.new(0, 0, -1)
	local slots = Formation.compute(origin, forward, dummyMembers, opts)

	-- Return the slot's position (which is already relative to origin)
	return slots[slotIndex]
end

return Formation
