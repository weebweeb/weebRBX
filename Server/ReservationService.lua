-- ReservationService
-- Handles private server reservations
-- @a_lyve

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DBug = require(ReplicatedStorage.Packages.DBugger)
--// Initialize logger
local log = DBug.new("ReservationService")
local PLACE_ID = game.PlaceId

local Reservation = {}
Reservation.__index = Reservation

Reservation.IsReservedServer = false
Reservation.TeleportData = nil
Reservation.AllPlayersHere = false


function Reservation.new(playerList, GameInfo)
	assert(typeof(playerList) == "table", "playerList must be a table of Players")
	assert(GameInfo ~= nil, "GameInfo cannot be nil")
	return setmetatable({
		Players = playerList,
		GameInfo = GameInfo,
	}, Reservation)
end


function Reservation:Start()
	local code = TeleportService:ReserveServer(PLACE_ID)
	local playersNeeded = {}
	for i, v in pairs(self.Players) do
		table.insert(playersNeeded, v.Name)
	end
	local data = {
		Players = playersNeeded,
		Map = self.GameInfo.Map.Name,
		Owner = self.GameInfo.Owner
	}

	local validPlayers = {}
	for _, plr in ipairs(self.Players) do
		if plr.Parent == Players then
			table.insert(validPlayers, plr)
		end
	end
	
	local TeleportOptions = Instance.new("TeleportOptions")
	TeleportOptions:SetTeleportData(data)
	TeleportOptions.ReservedServerAccessCode = code
	--TeleportOptions.ShouldReserveServer = true

	TeleportService:TeleportAsync(
		PLACE_ID,
		validPlayers,
		TeleportOptions)
end


local function getServerType()
	if game.PrivateServerId ~= "" then
		if game.PrivateServerOwnerId ~= 0 then
			return "VIPServer"
		else
			return "ReservedServer"
		end
	else
		return "StandardServer"
	end
end

function Reservation._DetectReserved()
	-- Reserved server
	if getServerType() == "ReservedServer" then
		Reservation.IsReservedServer = true
		
		
	end
	log:Info("This is a "..getServerType())
end

Reservation._DetectReserved()






return Reservation

