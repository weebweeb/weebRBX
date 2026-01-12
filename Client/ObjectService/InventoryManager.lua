--!strict
-- Inventory/backpack manager. Drop-in replacement for the default roblox backpack system, intended to be used in coordination with ObjectManager.
--@a_lyve

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local weightchangeEvent = game.ReplicatedStorage.Remotes:WaitForChild("WeightChangeEvent")
local RefreshInventory = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RefreshInventory")

local LocalPlayer = Players.LocalPlayer :: Player

export type InventoryClient = {
	Slots: {Tool?},
	SelectedSlot: number?,
	Hotbar: Frame,
	WeightTracker: TextLabel,
	BackpackItems: {},
	_connections: {RBXScriptConnection},

	EquipSlot: (self: InventoryClient, slot: number) -> (),
	Unequip: (self: InventoryClient) -> (),
	RefreshUI: (self: InventoryClient) -> (),
	BindInputs: (self: InventoryClient) -> (),
	Destroy: (self: InventoryClient) -> (),
	BindExternalToolDetection: (self: InventoryClient) -> ()
}

local InventoryClient = {}
InventoryClient.__index = InventoryClient

local MAX_SLOTS = 4


local function disableDefaultBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

local function getCharacter(): Model?
	return LocalPlayer.Character
end

local function getHumanoid(): Humanoid?
	local char = getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- Creates a new inventory controller
function InventoryClient.new(): InventoryClient
	disableDefaultBackpack()

	local self: InventoryClient = setmetatable({}, InventoryClient)

	self.Slots = table.create(MAX_SLOTS)
	self.SelectedSlot = nil
	self.BackpackItems = {}
	self.Hotbar = LocalPlayer.PlayerGui:WaitForChild("PlayerUI"):WaitForChild("Frame"):WaitForChild("HotBars")
	self.WeightTracker = LocalPlayer.PlayerGui.PlayerUI.Frame:WaitForChild("CarriedWeight")
	
	self._connections = {}

	self:BindInputs()
	self:RefreshUI()

	return self
end


function InventoryClient:EquipSlot(slot: number)
	assert(slot >= 1 and slot <= MAX_SLOTS, "Invalid slot index")

	if self.SelectedSlot == slot then
		self:Unequip()
		return
	end
	
	if self.SelectedSlot then
		self:Unequip()
	end

	local tool = self.Slots[slot] :: Tool
	if not tool then
		self:Unequip()
		return
	end

	local humanoid = getHumanoid()
	if not humanoid then
		return
	end


	humanoid:UnequipTools()
	tool.Parent = getCharacter()

	self.SelectedSlot = slot
	self:RefreshUI()
end

function InventoryClient:Unequip()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid:UnequipTools()
	end

	self.SelectedSlot = nil
	self:RefreshUI()
end

-- Pulls tools from Backpack into fixed slots
function InventoryClient:RescanBackpack()
	--table.clear(self.Slots)

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local character = LocalPlayer.Character
	if not backpack or not character or #self.Slots > MAX_SLOTS then
		return
	end

	local index = 0
	
	
	for i = 1, #self.Slots do
		if self.Slots[i] and (not self.Slots[i].Parent or self.Slots[i].Parent == workspace) then
			self.Slots[i] = nil
		end
	end
	
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and not tool:GetAttribute("ItemSlot") and not self.BackpackItems[tool] then
			repeat index += 1; if index > MAX_SLOTS then index = 1 end; until not self.Slots[index]
			self.Slots[index] = tool
			self.BackpackItems[tool] = tool
			tool:SetAttribute("ItemSlot", index)
		end
	end
	
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and not tool:GetAttribute("ItemSlot") and not self.BackpackItems[tool] then
			repeat index += 1; if index > MAX_SLOTS then index = 1 end; until not self.Slots[index]
			self.Slots[index] = tool
			self.BackpackItems[tool] = tool
			tool:SetAttribute("ItemSlot", index)
		end
	end
	
	
end

function InventoryClient:RefreshUI()
	self:RescanBackpack()

	for i = 1, MAX_SLOTS do
		local button = self.Hotbar:FindFirstChild("Slot" .. i)
		if not button or not button:IsA("ImageButton") then
			continue
		end

		local icon = button:FindFirstChild("ItemIcon")
		local textIcon = button:FindFirstChild("ItemName")
		local tool = self.Slots[i] :: Tool
		local chargebar = button:FindFirstChild("BarBG")
		assert(chargebar and textIcon, "UI elements missing! Check InventoryManager")
		if not tool then 
			icon.Image = ""
			icon.Visible = false
			textIcon.Visible = false
			button.Image = "rbxassetid://109391035611722"
			chargebar.Visible = false
			continue 
		end

		if icon and icon:IsA("ImageLabel") then
			if tool and tool.TextureId ~= "" then
				icon.Image = tool.TextureId
				icon.Visible = true
				textIcon.Visible = false
			else
				icon.Visible = false
				textIcon.Visible = true
				textIcon.Text = tool and tool.Name or ""
			end
		end
		
		if tool and tool:GetAttribute("MaxCharges") and tool:GetAttribute("MaxCharges") > 0 and tool:GetAttribute("Charges") then
			chargebar.Visible = true
			local charge = tool:GetAttribute("Charges") / tool:GetAttribute("MaxCharges")
			chargebar.Fill.Size = UDim2.new(charge, 0, chargebar.Fill.Size.Y.Scale, 0)
		else
			chargebar.Visible = false
		end

		-- Visual state (selection)
		button.AutoButtonColor = false
		if self.SelectedSlot == i then
			button.Image = "rbxassetid://70517609396960"
		else
			button.Image = "rbxassetid://109391035611722"
		end
	end
end




function InventoryClient:BindInputs()
	-- Keyboard 1–4
	local uisconnection = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key.Value >= Enum.KeyCode.One.Value and key.Value <= Enum.KeyCode.Four.Value then
				local slot = (key.Value - Enum.KeyCode.One.Value) + 1
				self:EquipSlot(slot)
			end
		end
	end)
	table.insert(self._connections, uisconnection)

	-- UI clicks
	for i = 1, MAX_SLOTS do
		local button = self.Hotbar:WaitForChild("Slot" .. i) :: ImageButton
		local buttonconnection = button.Activated:Connect(function()
			self:EquipSlot(i)
		end)
		table.insert(self._connections, buttonconnection)
	end

	-- Backpack changes
	local backpack = LocalPlayer:WaitForChild("Backpack")
	local backpackadded = backpack.ChildAdded:Connect(function()
		self:RefreshUI()
	end)
	local backpackremoved = backpack.ChildRemoved:Connect(function()
		self:RefreshUI()
	end)
	table.insert(self._connections, backpackadded)
	table.insert(self._connections, backpackremoved)
	-- Character monitoring 
	local function bindCharacter(char: Model)
		local characterbind = char.ChildAdded:Connect(function(child)
			if not child:IsA("Tool") then 
				return
			end
			self:RefreshUI()
		end)
		table.insert(self._connections, characterbind)
	end

	if LocalPlayer.Character then
		bindCharacter(LocalPlayer.Character)
	end

	local characterbind = LocalPlayer.CharacterAdded:Connect(bindCharacter)
	table.insert(self._connections, characterbind)
	
	local refreshinventory = RefreshInventory.OnClientEvent:Connect(function()
		self:RefreshUI()
	end)
	table.insert(self._connections, refreshinventory)
	
	-- Carried item tracker (server authoritative)
	local weightchange = weightchangeEvent.OnClientEvent:Connect(function(weight)
		self.WeightTracker.Text = tostring(weight).."Kg"
	end)
	table.insert(self._connections, weightchange)
end

function InventoryClient:Destroy()
	self:Unequip()
	table.clear(self.Slots)
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
end

return InventoryClient

