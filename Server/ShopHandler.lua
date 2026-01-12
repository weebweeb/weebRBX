--!strict
-- Shophandler
-- @a_lyve

local RunService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local remotesFolder = game.ReplicatedStorage:WaitForChild("Remotes")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopHandler = {}
ShopHandler.__index = ShopHandler


local function ensureRemote(name: string, remoteType: any?)
	local r = remotesFolder:FindFirstChild(name)
	remoteType = remoteType or "RemoteEvent"
	if not r then
		r = Instance.new(remoteType)
		r.Name = name
		r.Parent = remotesFolder
	end
	return r
end




-- Instantiates a new shophandler instance. This should only be called once per game total.
function ShopHandler.new(initialMap: Instance, ItemServer: any)
	local self = setmetatable({}, ShopHandler)
	assert(initialMap:FindFirstChild("ShopPlatform"), "Shop is missing ShopPlatform! Check the example shop map!")

	self.CurrentMap = initialMap
	self.Active = false
	self.BuyItemRemote = ensureRemote("BuyItemShop")
	self.GetItemRemote = ensureRemote("GetAvailableItemsItemShop")
	self.ItemShopVisibleRemote = ensureRemote("ItemShopVisible")
	self.Level = 0
	self.ItemsServer = ItemServer
	self.Items = nil
	self.PlayersShopping = {}
	self.Cash = 100
	self.ItemStock = {}
	self.ShopPlatform = initialMap:WaitForChild("ShopPlatform")

	self._promptconn = nil
	self._conn = nil
	self._getavailableitemsconn = nil
	self._buyitemconn = nil
	self._itemshopvisibleconn = nil

	return self
end

-- Updates the shop stock based on the current level
function ShopHandler:UpdateShopStock()
	local relevantDefinitions = {}
	self.ItemStock = {}
	self.ItemsServer:RemoveAllItems()
	for i, v in pairs(self.ItemsServer:GetDefinitions()) do
		if v.Meta and v.Meta.Value and v.Meta.ShopLevel and v.Meta.ShopLevel <= self.Level then
			table.insert(relevantDefinitions, v)
		end
	end

	for i, v in pairs(relevantDefinitions) do
		local luck
		local calculatedluck = (v.Meta.ShopStats.Luck+((v.Meta.ShopStats.Luck/2)*self.Level)*10)
		if v.Meta.ShopStats.Luck == 1 then calculatedluck = 10 end
		if calculatedluck < 10 then
			luck = math.random(calculatedluck, 10)
			else luck = 10
		end
		if luck == 10 then
			self.ItemStock[v.Name] = v
		end

		--self.ItemsServer:spawnItem(v[math.random(1, #v) or 1].Name, "item_"..tostring(httpService:GenerateGUID()), Vector3.new(self.ShopBuyButton.Position.X + math.random(-10, 10), self.ShopBuyButton.Position.Y, self.ShopBuyButton.Position.Z + math.random(-10, 10)), true) -- spawn in random places for now
	end

	self.Items = self.ItemsServer:getAllItems()


end

-- Updates the group's owned cash to the passed variable. Pass "nil" to hide the cash label
function ShopHandler:UpdateCashOwned(cash)
	if cash then
		self.Cash = cash
	end
	game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateCash"):FireAllClients(cash)
end

-- Called every heartbeat while active
function ShopHandler:Update()
	if not self.Active then return end
	if not self.ShopPlatform then return end
	local PlayersNearby = workspace:GetPartBoundsInRadius(self.ShopPlatform.Position, 10)
	local playersnearby = {}
	for i, v in pairs(PlayersNearby) do
		local pl = game.Players:GetPlayerFromCharacter(v.Parent)
		if pl then
			if not table.find(playersnearby, pl.Name) then
				table.insert(playersnearby, pl.Name)
			end
			if not table.find(self.PlayersShopping, pl.Name) then
				table.insert(self.PlayersShopping, pl.Name)
				game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemShopVisible"):FireClient(pl, true)
			end
		end
	end

	for i, v in pairs(self.PlayersShopping) do
		if not table.find(playersnearby, v) then
			table.remove(self.PlayersShopping, i)
			local player : any? = game.Players:FindFirstChild(v)
			if player then
				game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemShopVisible"):FireClient(player, false)
			end
		end
	end
end

-- Stops active checking
function ShopHandler:Stop()
	self.Active = false
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._promptconn then
		self._promptconn:Disconnect()
		self._promptconn = nil
	end
	if self._getavailableitemsconn then
		self._getavailableitemsconn:Disconnect()
		self._getavailableitemsconn = nil
	end
	if self._buyitemconn then
		self._buyitemconn:Disconnect()
		self._buyitemconn = nil
	end
	if self._itemshopvisibleconn then
		self._itemshopvisibleconn:Disconnect()
		self._itemshopvisibleconn = nil
	end
	
	for i, v in pairs(self.PlayersShopping) do
		local player : any? = game.Players:FindFirstChild(v)
		if player then
			game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemShopVisible"):FireClient(player, false)
		end
	end
	self.PlayersShopping = {}
end

-- Starts ShopHandler
function ShopHandler:Start()
	if self.Active then return end
	self.Active = true

	self._conn = RunService.Heartbeat:Connect(function()
		self:Update()
	end)

	self.GetItemRemote.OnServerInvoke = function(player)
		return self.ItemStock
	end

	self._buyitemconn = self.BuyItemRemote.OnServerEvent:Connect(function(player, itemDef)
		if not self.Active then return end
		if not itemDef then return end
		if not self.ItemStock[itemDef] then return end
		if not self.Items then return end
		local definitions = self.ItemsServer:GetDefinitions()
		if not definitions[itemDef] then return end
		local item = definitions[itemDef]
		if self.Cash < item.Meta.ShopStats.Price then return end
		self.Cash -= item.Meta.ShopStats.Price
		local itemId = "item_"..tostring(httpService:GenerateGUID())
		local char = player.Character
		if not char then return end
		local hrp = char:WaitForChild("HumanoidRootPart")
		if not hrp then return end
		local spawneditem = self.ItemsServer:spawnItem(itemDef, itemId, Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z), true)
		self.ItemsServer:GivePlayerItem(player, spawneditem.Id)
		self:UpdateCashOwned(self.Cash)
	end)




end

-- Advances to next level & refreshes shop
function ShopHandler:NextLevel(newMap: Instance, newLevel: number)
	self:Stop()

	self.CurrentMap = newMap
	self.Level = newLevel

	self.lastValue = 2
	self.TotalValue = 0

	self:UpdateShopStock()

	self:Start()
end

return ShopHandler

