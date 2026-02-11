-- GlobalWeaponConfigTable
-- Universal table of weapon configs which is read-only for clients, but read/write for server
-- When indexing and utilizing this, the name of the tool should match the name/index of the config table
-- a_lyve/weebweeb

local GlobalWeaponConfigTable = {}


-- Instantiates a new config to add to the global weapon config table
GlobalWeaponConfigTable.InstantiateNewConfig = function(name : string, cooldown : number, maxHitBoxDuration : number)
	if GlobalWeaponConfigTable[name] then warn("GlobalWeaponConfigTable: Config already exists for item "..tostring(name)) return end
	local ServerScriptService = game:GetService("ServerScriptService")
	local WeaponConfigurationBase = require(ServerScriptService:WaitForChild("Weapon"):WaitForChild("WeaponConfigurationBase"))
	local configTemplate = WeaponConfigurationBase.new(name, cooldown, maxHitBoxDuration)
	GlobalWeaponConfigTable[name] = configTemplate
	return configTemplate
end

return GlobalWeaponConfigTable
