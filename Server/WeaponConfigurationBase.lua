-- WeaponConfigurationBase
-- Base class intended for defining weapon, hitbox configuration, should be located in ServerScriptService for safety
-- a_lyve/weebweeb
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfiguration = {}
WeaponConfiguration.__index = WeaponConfiguration



export type WeaponConfiguration = {
	Name: string, -- the name of the weapon, will be used to index these configurations
	Cooldown : number, -- How many seconds before a weapon can be used again, influences server-side hitbox cooldown
	MaxHitBoxDuration: number, -- Maximum amount of time a hitbox can be set as enabled with this weapon
	HitBoxFolderName : string, -- name of the folder which holds hitbox parts, should be a direct descendant of the tool.
	Damage: number -- How much damage to deal per hit

}



-- Instantiates WeaponConfiguration class
function WeaponConfiguration.new(name: string, cooldown : number, maxHitBoxDuration: number, hitBoxFolderName : string?, damage : number?)
	local self = setmetatable({}, WeaponConfiguration)
	self.Name = name
	self.Cooldown = cooldown
	self.MaxHitBoxDuration = maxHitBoxDuration
	self.HitBoxFolderName = hitBoxFolderName or "Hitboxes"
	self.Damage = damage or 10
	

	return self
end

return WeaponConfiguration

