-- ServerScriptService.MatchmakingHandler
-- @a_lyve


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchmakingEvent = Remotes:WaitForChild("MatchmakingEvent")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local GamemodeHandler = require(ServerScriptService:WaitForChild("GamemodeHandler"))
local HttpService = game:GetService("HttpService")
local Reservation = require(script.Parent.ReservationService)
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")


local CountDownBillboard = game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Misc").Countdown



local ZonesFolder = workspace:WaitForChild("MatchmakingZones")


local runningGameModes = {}

-- Data for active queues
local Queues = {}  
--[[
Queues[zone] = {
    Owner = Player or nil,
    Players = { Player1, Player2, ... },
    Started = false,
    TimeoutThread = thread or nil,
}
]]

local ZONES = {}
-- ZONES[zone] = {
--    CurrentPlayers = { [player] = true }
-- }


local ElevatorObjects = {}

local function ensureQueue(zone)
	if not Queues[zone] then
		Queues[zone] = {
			Owner = nil,
			Id = HttpService:GenerateGUID(false),
			Players = {},
			Started = false,
			TimeoutThread = nil,
			RequiredCount = 4,
			FriendsOnly = false,
			CountdownRunning = false
		}
	end
	return Queues[zone]
end

local function ensureZoneState(zone)
	if not ZONES[zone] then
		ZONES[zone] = { CurrentPlayers = {} }
	end
	return ZONES[zone]
end

local function getPlayersInside(zone)
	local playersInside = {}

	local part = zone:IsA("BasePart") and zone or zone.PrimaryPart
	if not part then
		return playersInside
	end

	local parts = workspace:GetPartsInPart(part)

	for _, p in ipairs(parts) do
		local char = p:FindFirstAncestorOfClass("Model")
		if char then
			local plr = Players:GetPlayerFromCharacter(char)
			if plr then
				playersInside[plr] = true
			end
		end
	end

	return playersInside
end


local function clearQueue(zone, waittime)
	waittime = waittime or 4
	task.delay(waittime, function()
		if not zone then return end
		Queues[zone] = nil
		OpenElevatorDoors(zone.AssociatedElevator.Value)
	end)
end



local function processActiveQueues()
	for zone, q in pairs(Queues) do


		local billboard = zone:FindFirstChild("Countdown")
		if not billboard or not billboard:IsA("BillboardGui") then
			warn("Zone missing Countdown BillboardGui:", zone.Name)
			q.CountdownRunning = false
			continue
		end

		local label = billboard:FindFirstChild("CountDown")
		if not label or not label:IsA("TextLabel") then
			warn("TextFrame missing CountDown TextLabel:", zone.Name)
			q.CountdownRunning = false
			continue
		end

		if q.Started == true and zone and zone:IsA("BasePart") then
			if q.CountdownRunning then
				continue
			end
			q.CountdownRunning = true

			billboard.Enabled = true

			task.spawn(function()

				local function EnsurePlayersInside(localzone, que)
					local state = ensureZoneState(localzone)

					local insideNow = getPlayersInside(localzone)

					for plr in pairs(state.CurrentPlayers) do
						if not insideNow[plr] then
							state.CurrentPlayers[plr] = nil

							if que.Owner and (plr == que.Owner or plr.Name == que.Owner.Name) then
								que.Owner = nil
								for i, v in pairs(que.Players) do
									if v == plr then
										que.Players[i] = nil
									end
								end
							end
						end
					end
				end


				local seconds = 20
				local Owner = q.Id
				runningGameModes[Owner] = GamemodeHandler.new()
				local newGame = runningGameModes[Owner]
				newGame.RequiredPlayers = q.RequiredCount
				newGame:PreLoadMap()
				while seconds > 0 do
					EnsurePlayersInside(zone, q)
					if #q.Players == 1 then
						task.wait(0.5)
						else
						task.wait(1)
					end
					seconds -= 1
					if q.FriendsOnly then
						label.Text = tostring(seconds).."\n"..tostring(#q.Players).."/"..tostring(q.RequiredCount).."\n".."Friends Only"
					else
						label.Text = tostring(seconds).."\n"..tostring(#q.Players).."/"..tostring(q.RequiredCount)
					end
					if not q.Owner then if #q.Players > 0 then q.Owner = q.Players[1] else seconds = 0; break end end

				end
				billboard.Enabled = false
				q.CountdownRunning = false

				if q.Owner then
					CloseElevatorDoors(zone.AssociatedElevator.Value)
					newGame:AddPlayers(q.Players)

					runningGameModes[Owner]:ReserveServer()
				else
					clearQueue(zone, 0)
					newGame:Close()
					newGame = nil
					runningGameModes[Owner] = nil
					return 


				end
				clearQueue(zone, 1)
			end)
		else
			billboard.Enabled = false
			q.CountdownRunning = false

			if q.Owner and runningGameModes[q.Owner.Name] then runningGameModes[q.Owner.Name]:Close(); clearQueue(zone, 0) end
			if not q.Owner and #q.Players > 0 then clearQueue(zone, 0) end
		end
	end
end


local function isPlayerInsideZone(player, zone)
	local char = player.Character
	if not char or not char.PrimaryPart then
		return false
	end
	local playerPos = char.PrimaryPart.Position
	local zonePart = zone:IsA("BasePart") and zone or zone.PrimaryPart
	if not zonePart then
		return false
	end

	local center = zonePart.Position
	local radius = zonePart.Size.Magnitude / 2
	local distance = (playerPos - center).Magnitude
	return distance <= radius
end

local function respawnPlayerInstant(player)
	if player.Character then
		player:LoadCharacter()
	end
end


local function onPlayerEnteredZone(player, zone)
	local q = ensureQueue(zone)

	if table.find(q.Players, player) then return end

	-- First player becomes owner
	if not q.Owner then
		q.Owner = player
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("CreateGame")
		gui.Enabled = true

		-- Start a 20s timeout for inactivity
		q.TimeoutThread = task.spawn(function()
			local owner = player
			local startTime = os.clock()
			while os.clock() - startTime < 20 do
				task.wait(0.5)
				if q.Started == true then
					table.insert(q.Players, player)
					return
				end
			end
			local guiEnabled = owner:FindFirstChild("PlayerGui"):FindFirstChild("CreateGame")
			if not q.Started and ((guiEnabled and guiEnabled.Enabled) or not guiEnabled)  then
				respawnPlayerInstant(owner)
				gui.Enabled = false
				q.Owner = nil
				q.Players = {}
			end
		end)
	else
		if q.Started then
			if #q.Players < q.RequiredCount then
				if q.FriendsOnly and q.Owner and player ~= q.Owner then
					if player:IsFriendsWith(q.Owner.UserId) then
						table.insert(q.Players, player)
					else respawnPlayerInstant(player)
					end
				else
					table.insert(q.Players, player)

				end
			else
				respawnPlayerInstant(player)
			end
		end

	end

end

local function onPlayerExitedZone(player, zone)
	local q = ensureQueue(zone)

	for i, p in ipairs(q.Players) do

		if p == player or p.Name == player.Name then

			table.remove(q.Players, i)
			break
		end
	end
	
	

	-- If owner leaves before starting, cancel queue entirely
	if q.Owner == player and not q.Started then
		local gui = player:FindFirstChild("PlayerGui"):FindFirstChild("CreateGame")
		if gui then gui.Enabled = false end

		q.Owner = nil
		clearQueue(zone, 0)
	end

	if q.Owner == player and q.Started then

		q.Owner = nil
		--clearQueue(zone, 0)
	end

end




local function Weld(a: BasePart, b: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = a
	return weld
end

-- Prepares an elevator door model by welding everything to its PrimaryPart
local function SetupElevatorDoor(model: Model)
	local root = model.PrimaryPart
	local debounce = Instance.new("BoolValue", model)
	debounce.Name = "Open"
	if not root then
		error(("Model %s has no PrimaryPart"):format(model.Name))
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			if obj ~= root then
				obj.Anchored = false
				Weld(obj, root)
			end
		end
	end
end

-- Handles animation for opening/closing doors
local function AnimateDoor(doorModel: Model, distance: number, duration: number, open: boolean)
	if not doorModel.PrimaryPart then
		error(("Door model %s has no PrimaryPart"):format(doorModel.Name))
	end

	local primary = doorModel.PrimaryPart
	local rootCF = primary.CFrame
	local dir = rootCF.UpVector
	local offset = open and (dir * distance) or (dir * -distance)

	local goal = { CFrame = rootCF + offset }

	local tween = TweenService:Create(
		primary,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)

	tween:Play()
	return tween
end

-- Opens the elevator doors
function OpenElevatorDoors(elevator: Model)
	local elevator = elevator.Model
	local Elevatordoor1 = elevator.Door1
	local Elevatordoor2 = elevator.Door2
	if Elevatordoor1.Open.Value or Elevatordoor2.Open.Value then return end
	local DoorAnim1 = AnimateDoor(Elevatordoor1, 4, 2, true)
	local DoorAnim2 = AnimateDoor(Elevatordoor2, 4, 2, true)
	DoorAnim1.Completed:Connect(function() 
		Elevatordoor1.Open.Value = true
	end)

	DoorAnim2.Completed:Connect(function() 
		Elevatordoor2.Open.Value = true
	end)



end

-- Closes Elevator doors
function CloseElevatorDoors(elevator: Model)
	local elevator = elevator.Model
	local Elevatordoor1 = elevator.Door1
	local Elevatordoor2 = elevator.Door2
	if not Elevatordoor1.Open.Value or not Elevatordoor2.Open.Value then return end
	local DoorAnim1 = AnimateDoor(Elevatordoor1, 4, 2, false)
	local DoorAnim2 = AnimateDoor(Elevatordoor2, 4, 2, false)

	DoorAnim1.Completed:Connect(function() 
		Elevatordoor1.Open.Value = false
	end)

	DoorAnim2.Completed:Connect(function() 
		Elevatordoor2.Open.Value = false
	end)
end



for i, v in pairs(ZonesFolder:GetChildren()) do
	local CountDownBillboardInstance = CountDownBillboard:Clone()
	CountDownBillboardInstance.Parent = v
	local elevatorInstance = v.AssociatedElevator.Value
	if ElevatorObjects[elevatorInstance] then
		error("MatchmakingHandler: "..v.Name.." shares the same AssociatedElevator object as "..ElevatorObjects[elevatorInstance].." ! Ensure AssociatedElevator.value is correct")
	else
		SetupElevatorDoor(elevatorInstance.Model.Door1)
		SetupElevatorDoor(elevatorInstance.Model.Door2)

	end
	ElevatorObjects[elevatorInstance] = v

	OpenElevatorDoors(elevatorInstance)
end


task.spawn(function()
	while true do
		task.wait(1)
		processActiveQueues()
	end
end)

task.spawn(function()
	RunService.Heartbeat:Connect(function()
		for _, zone in ipairs(ZonesFolder:GetChildren()) do
			if zone:IsA("BasePart") then
				ensureQueue(zone)
				local state = ensureZoneState(zone)

				local insideNow = getPlayersInside(zone)

				-- ENTER
				for plr in pairs(insideNow) do
					if not state.CurrentPlayers[plr] then
						state.CurrentPlayers[plr] = true
						onPlayerEnteredZone(plr, zone)
					end
				end

				-- EXIT
				for plr in pairs(state.CurrentPlayers) do
					if not insideNow[plr] then
						state.CurrentPlayers[plr] = nil
						onPlayerExitedZone(plr, zone)
					end
				end
			end
		end
	end)
end)




-- Ties with ReservationService to start a game, handles a couple of initiator functions before passing the rest of the job off to GamemodeHandler
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Wait()
	if Reservation.IsReservedServer then
		local joinData = player:GetJoinData()
		if joinData and joinData.TeleportData and not Reservation.TeleportData then
			Reservation.TeleportData = joinData.TeleportData
		end
		local playerInfo = {}

		if Reservation.TeleportData.Players then
			for i = 1, #Reservation.TeleportData.Players do
				local playerObject = game.Players:FindFirstChild(Reservation.TeleportData.Players[i])
				if playerObject then
					Reservation.AllPlayersHere = true
					table.insert(playerInfo, playerObject)
				else
					Reservation.AllPlayersHere = false
					break
				end
			end
			if Reservation.AllPlayersHere then
				local gameInfo = Reservation.TeleportData.GameInfo
				local StartedGame = GamemodeHandler.new()
				StartedGame.Players = playerInfo
				local map = StartedGame:PreLoadMap()
				StartedGame:StartGame()
			else
				print("Waiting on other players..")
			end
		else warn("RESERVATIONSERVICE: Reserved a server but failed to process Teleportdata! Did something go wrong? TeleportData Dump:", Reservation.TeleportData)

		end
	end
end)

-- Expected Remote payload:
-- {
--   Player = Player,
--   Zone = zoneName,
--   Action = "Start" or "FriendsOnlyToggle" or "SetCount",
--   Value = string/int/bool
-- }


MatchmakingEvent.OnServerEvent:Connect(function(player, data)
	local zone = ZonesFolder:FindFirstChild(data.Zone)
	if not zone then return end

	local q = ensureQueue(zone)
	if q.Owner ~= player then
		return
	end
	
	local state = ensureZoneState(zone)

	local insideNow = getPlayersInside(zone)
	
	for plr in pairs(state.CurrentPlayers) do
		if not insideNow[plr] then
			state.CurrentPlayers[plr] = nil
			onPlayerExitedZone(plr, zone)
			return
		end
	end

	if data.Action == "Start" then
		q.Started = true
		q.RequiredCount = math.min(4, (q.RequiredCount or 4))
		q.FriendsOnly = q.FriendsOnly or false

		local gui = player.PlayerGui:FindFirstChild("CreateGame")
		if gui then gui.Enabled = false end

		if q.TimeoutThread then
			q.TimeoutThread = nil
		end

	elseif data.Action == "SetCount" then
		q.RequiredCount = tonumber(data.Value) or 4

	elseif data.Action == "FriendsOnlyToggle" then
		q.FriendsOnly = data.Value == true
	end
end)


