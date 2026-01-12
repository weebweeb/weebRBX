-- gamemode handler
-- @a_lyve

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Gamemode = require(script.Parent.GamemodeBase)
local ShopHandler = require(script.Parent.ShopHandler)
local MapLoader = require(script.Parent.MapLoader)
local ReservationService = require(script.Parent.ReservationService)
local ObjectService = require(game.ReplicatedStorage.Shared.ObjectService)
local QuotaHandler = require(script.Parent.QuotaHandler)

local handler = {}
handler.__index = handler

function handler.new()
	local self = setmetatable({}, handler)

	self.Gamemode = Gamemode.new()
	self.MapLoader = MapLoader.new()
	self.RequiredPlayers = 4
	self.CheckInterval = 1
	self.Players = {}
	self.Map = nil
	self.Reservation = nil
	self.Quota = nil
	self.Level = 0
	self.Portal = nil
	self.Shop = nil
	self.ShopHandler = nil
	self.ObjectServer = nil
	self.MissionCountDown = 120
	self.ShopCountDown = 60
	self.PortalEvent = nil
	self.SafePlayers = {}


	self._connections = {}

	self:_connectPlayerEvents()

	return self
end

function handler:AddPlayers(Players: Array)
	for _, player in ipairs(Players) do
		table.insert(self.Players, player)
	end
	for _, p in ipairs(self.Players) do
		self.Gamemode:AddPlayer(p)
	end
end

function handler:_connectPlayerEvents()

	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self.Gamemode:RemovePlayer(player)
	end))

end

function handler:PreLoadMap()
	if self.Map then self.Map:Destroy(); self.Map = nil end
	self.Map = self.MapLoader:LoadRandom()
	return self.Map
end

function handler:ReserveServer()
	if not RunService:IsStudio() then
		self.Reservation = ReservationService.new(self.Players, self)
		self.Reservation:Start()
		self:Close()
	else
		self:StartGame()
	end
end


function handler:Close()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	if self.Map then
		self.Map:Destroy()
	end
end


function handler:NewRound()
	self.MissionCountDown = 120
	self.ShopCountDown = 60
	self.Level += 1
	self.SafePlayers = {}
	local players = self.Players
	if #players >= 1 then
		if not self.Shop then
			self.Shop = self.MapLoader:LoadSpecific(game.ReplicatedStorage.Assets.Misc.PlaceholderShop)
		end
		local map = self.Map or self.MapLoader:LoadRandom()
		
		self.Portal = map:FindFirstChild("Portal")
		self.Gamemode.CurrentMap = map

		self:_teleportPlayers(players, map)
		if self.Level < 2 then
			self.ObjectServer = ObjectService.Server.new({
				SpawnFolder = workspace:FindFirstChild("Items") or (function() local f=Instance.new("Folder"); f.Name="Items"; f.Parent=workspace; return f end)(),
				ChunkSize = 60,
				PickupDistance = 6,
				ReplicateTick = 0.4,
				AllowedPickupInterval = 5
			})
		else
			self.ObjectServer:RemoveAllItems()
		end
		if not self.ShopHandler then
			self.ShopHandler = ShopHandler.new(self.Shop, self.ObjectServer)
			self.ShopHandler:Start()
			self.ShopHandler:NextLevel(self.Shop, self.Level)
		else
			self.ShopHandler:NextLevel(self.Shop, self.Level)
		end
		self.ShopHandler:UpdateCashOwned(nil)


		-- example
		for i=1,50 do
			self.ObjectServer:spawnItem("ExampleScrap", "item_"..i, Vector3.new(map.Spawn.Position.X + math.random(-500,500), map.Spawn.Position.Y, map.Spawn.Position.Z + math.random(-500,500)))
		end

		for i=1,50 do
			self.ObjectServer:spawnItem("HeavyScrap", "item_"..50+i, Vector3.new(map.Spawn.Position.X + math.random(-500,500), map.Spawn.Position.Y, map.Spawn.Position.Z + math.random(-500,500)))
		end
		
		for i=1,50 do
			self.ObjectServer:spawnItem("ExampleMediumScrap", "item_"..100+i, Vector3.new(map.Spawn.Position.X + math.random(-500,500), map.Spawn.Position.Y, map.Spawn.Position.Z + math.random(-500,500)))
		end
		
		for i=1,50 do
			self.ObjectServer:spawnItem("ExampleHeavyCarryableScrap", "item_"..150+i, Vector3.new(map.Spawn.Position.X + math.random(-500,500), map.Spawn.Position.Y, map.Spawn.Position.Z + math.random(-500,500)))
		end

		if self.Level > 1 then
			self.Quota:NextLevel(self.Map, self.Level)
		else
			self.Quota = QuotaHandler.new(self.Map, self.Level, self.ObjectServer:getAllItems())
			self.Quota:Start()-- start quota handler
		end
		self.Quota.Active = true

		if self.PortalEvent then
			self.PortalEvent:Disconnect()
		end
		self.PortalEvent = self.Portal.Touched:Connect(function(part)
			local player = game.Players:GetPlayerFromCharacter(part.Parent) 
			if player and self.Portal.Transparency < 1 and not table.find(self.SafePlayers, player) then
				self.ShopHandler:UpdateCashOwned(self.ShopHandler.Cash + self.Quota.Quota)

				self:_teleportPlayers({player}, self.Shop)
				table.insert(self.SafePlayers, player)
			end
		end)
	end
end

function handler:StartGame()
	task.wait(self.CheckInterval)
	self:_connectPlayerEvents()
	self:NewRound()

	-- update objects
	task.spawn(function()
		while true do
			self.ObjectServer:chunkedScanForNearbyPlayers(80)
			task.wait(1)

			if self.Quota.QuotaMet then
				self.Portal.Transparency = 0.9
				if self.MissionCountDown > 0 then
					self.MissionCountDown -= 1
					self.Quota.QuotaSubtextChangeRemote:FireAllClients("PORTAL OPEN")
					self.Quota.QuotaRemote:FireAllClients(tostring(self.MissionCountDown))
					if #self.SafePladyers == #self.Players then
						self.MissionCountDown = 0
					end
				else
					if self.ShopCountDown > 0 then
						if self.ShopCountDown == 50 then
							self:PreLoadMap()
						end
						self.ShopCountDown -= 1
						self.Quota.Active = false
						self.Quota.QuotaSubtextChangeRemote:FireAllClients("SHOP")
						self.Quota.QuotaRemote:FireAllClients(tostring(self.ShopCountDown))
					else
						self:NewRound()
					end
				end



			end
		end
	end)
end




function handler:_teleportPlayers(players, map)
	local spawn = map:FindFirstChild("Spawn")
	if not spawn or not spawn:IsA("BasePart") then
		warn("Map missing 'Spawn' object")
		return
	end

	for _, player in ipairs(players) do
		task.spawn(function()
			local char = player.Character or player.CharacterAdded:Wait()
			player.PlayerGui:WaitForChild("PlayerUI").Enabled = true
			player.PlayerGui:WaitForChild("MainUI").Enabled = false
			char:PivotTo(spawn.CFrame)
		end)
	end


end

return handler.new()
