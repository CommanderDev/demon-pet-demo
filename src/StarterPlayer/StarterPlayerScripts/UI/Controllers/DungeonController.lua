local DungeonController = {}

function DungeonController.Init(self, node, tree)
	self.instance = node.Instance

	self.updateWave = function(data: number)
		self.instance.InformationLabel.Text = "Wave " .. data.wave .. "/" .. data.maxWave
	end

	self.enteredDungeon = function(data: { any })
		self.instance.Visible = true
		self.updateWave(data)
	end

	tree:Subscribe("UpdateWave", self.updateWave)
	tree:Subscribe("EnteredDungeon", self.enteredDungeon)
end

return DungeonController
