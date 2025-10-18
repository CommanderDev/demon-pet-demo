--!strict
--[[
    Description: Allow many nodes in a group to be open simultaneously
]]
    
local Root = script.Parent.Parent

local Types = require(Root.Core.Types)
local ZIndexManager = require(Root.Core.ZIndexManager)

type Tree = Types.Tree
type Node = Types.Node

local MultiPolicy = {}
MultiPolicy.__index = MultiPolicy

function MultiPolicy.OnOpen(_tree: Tree, node: Node): ()
    ZIndexManager.BringToFront(node)
end

function MultiPolicy.OnClose(_tree: Tree, node: Node): ()
    -- Do nothing
end

return MultiPolicy