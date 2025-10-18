--!strict

local RunService = game:GetService("RunService")

local Hub = {}
Hub.__index = Hub

type Entry = {
    node: any,
    fn: (...any) -> (),
    whenOpen: boolean?,
    whenVisible: boolean?,
    dead: boolean?,
}

local subs = {
	tick = {} :: {Entry},
	render = {} :: {Entry},
	second = { t = 0, list = {} :: {Entry} },
}

local connections: { [string]: RBXScriptConnection?} = { tick = nil, render = nil}

local function shouldRun(entry: Entry): boolean
    local node = entry.node
    if not node or not node.Instance or not node.Instance.Parent then return false end
    if entry.whenOpen and not node.Open then return false end
    if entry.whenVisible and (not node.Instance.Visible) then return false end
    return true
end

local function pump(list: {Entry}, dt: number): ()
    for index = #list, 1, -1 do 
        local entry = list[index]
        if entry.dead then 
            table.remove(list, index)
        elseif shouldRun(entry) then 
            entry.fn(dt, entry.node)
        end 
    end
end

local function pumpSecond(dt: number): ()
    local bucket = subs.second
    bucket.t += dt
    if bucket.t < 1 then return end
    local whole = math.floor(bucket.t)
    bucket.t -= whole
    local list = bucket.list
    for index = #list, 1, -1 do
        local entry = list[index]
        if entry.dead then 
            table.remove(list, index)
        elseif shouldRun(entry) then
            entry.fn(whole, entry.node)
        end
    end
end

local function ensure(): ()
    if not connections.tick then 
        connections.tick = RunService.Heartbeat:Connect(function(dt: number): ()
            pump(subs.tick, dt)
            pumpSecond(dt)
        end)
    end

    if not connections.render then 
        connections.render = RunService.RenderStepped:Connect(function(dt: number): ()
            pump(subs.render, dt)
        end)
    end
end

local function add(list: {Entry}, node: any, fn: (...any) -> (), opts: {whenOpen: boolean?, whenVisible: boolean?}?): () -> ()
    ensure()
    local entry: Entry = {
        node = node,
        fn = fn,
        whenOpen = opts and opts.whenOpen or false,
        whenVisible = opts and opts.whenVisible or false,
    }
    table.insert(list, entry)
    return function() entry.dead = true end
end

function Hub.Add(phase: "tick" | "render" | "second", node: any, fn: (...any) -> (), opts: {whenOpen: boolean?, whenVisible: boolean?}?): () -> ()
    if phase == "tick" then
        return add(subs.tick, node, fn, opts)
    elseif phase == "render" then 
        return add(subs.render, node, fn, opts)
    elseif phase == "second" then 
        return add(subs.second.list, node, fn, opts)
    else
        error("Invalid phase: " .. phase)
    end
end

return Hub