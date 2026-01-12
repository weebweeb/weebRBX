local ServicesFolder = script.Parent.Parent
local ToolServiceFolder = ServicesFolder:WaitForChild("ToolService")
local ToolService = require(ToolServiceFolder.ToolService)

local Inventories = {}
local InventoryService = {}

local MAX_SLOTS = 4

function InventoryService:InitPlayer(player)
	Inventories[player] = {
		Slots = table.create(MAX_SLOTS),
		EquippedSlot = nil
	}
end

function InventoryService:RemovePlayer(player)
	Inventories[player] = nil
end

function InventoryService:GetInventory(player)
	return Inventories[player]
end

function InventoryService:_replicate(player)
	local char = player.Character
	if not char then return end
	
	for i=1, MAX_SLOTS do
		char:SetAttribute("InvSlot"..i, Inventories[player].Slots[i])
	end
	
	char:SetAttribute("EquippedSlot", Inventories[player].EquippedSlot)
end

function InventoryService:AddItem(player, ToolId)
	local inv = Inventories[player]
	if not inv then return end
	
	for i=1, MAX_SLOTS do
		if not inv.Slots[i] then
			inv.Slots[i] = ToolId
			self:_replicate(player)
			return true
		end
	end
	
	return false
end

function InventoryService:RemoveItem(player, slot)
	local inv = Inventories[player]
	if not inv then return end
	
	local ToolId = inv.Slots[slot]
	if not ToolId then return end
	
	if inv.EquippedSlot == slot then
		ToolService:Unequip(player)
		inv.EquippedSlot = nil
	end
	
	inv.Slots[slot] = nil
	self:_replicate(player)
end

function InventoryService:EquipSlot(player, slot)
	local inv = Inventories[player]
	if not inv then return end

	local toolId = inv.Slots[slot]
	if not toolId then return end

	if inv.EquippedSlot == slot then
		ToolService:Unequip(player)
		inv.EquippedSlot = nil
		self:_replicate(player)
		return
	end

	inv.EquippedSlot = slot
	ToolService:Equip(player, toolId)
	self:_replicate(player)
end

return InventoryService
