local InventoryController = {}

function InventoryController.Init(self, node, tree)
	self.instance = node.Instance

	self.addToInventory = function(entry) end
	self.removeFromInventory = function(entry) end
	self.initInventory = function() end

	tree:Subscribe("addToInventory", self.addToInventory)
	tree:Subscribe("removeFromInventory", self.removeFromInventory)
	tree:Subscribe("initInventory", self.initInventory)
end

return InventoryController
