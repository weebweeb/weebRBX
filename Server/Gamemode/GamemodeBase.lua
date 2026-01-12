-- a_lyve/weebweeb
--!strict

local Gamemode = {}
Gamemode.__index = Gamemode

function Gamemode.new()
	local self = setmetatable({}, Gamemode)
	self.Players = {}
	self.CurrentMap = nil
	return self
end

function Gamemode:AddPlayer(player)
	self.Players[player.UserId] = player
end

function Gamemode:RemovePlayer(player)
	self.Players[player.UserId] = nil
end

function Gamemode:GetPlayers()
	local list = {}
	for _, plr in pairs(self.Players) do
		table.insert(list, plr)
	end
	return list
end

return Gamemode
