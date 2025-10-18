--!strict
--[[
    Description: Only one node open per groupp
]]

local Root = script.Parent.Parent

local Types = require(Root.Core.Types)
type Tree = Types.Tree
type Node = Types.Node

local Mutex = {}

function Mutex.onOpen(tree: Tree, node: Node): ()
    -- Close every **other** open node in this group
    if not node.Group then return end
    tree:Begin()
    for _, other in pairs(tree.Groups[node.Group] or {}) do
        if other ~= node and other.Open then 
            tree:Close(other.Key)
        end
    end
    tree:Commit()
end

function Mutex.onClose(tree: Tree, node: Node): ()
    -- No special behavior
end

return Mutex