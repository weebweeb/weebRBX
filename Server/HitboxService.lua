-- HitboxService
-- Hitbox manager for Weapon class, should only be instantiated once
-- a_lyve/weebweeb
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local getDescendantsOfType = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GetDescendantsOfType"))
local findAllPartsOnRay = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("FindAllPartsOnRay"))

local GlobalWeaponConfigTable = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GlobalWeaponConfigTable"))

local remotesFolder : any = game.ReplicatedStorage:FindFirstChild("Remotes")
local maxHitboxTime = 1


local function assertRemoteEvent(name: string)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Parent = game.ReplicatedStorage
		remotesFolder.Name = "Remotes"
	end

	if not remotesFolder:FindFirstChild(name) then
		local Remote = Instance.new("RemoteEvent")
		Remote.Name = name
		Remote.Parent = remotesFolder
		return Remote
	else
		local Remote : any = remotesFolder:FindFirstChild(name) 
		return Remote
	end
end

local SetHitboxEnabled = assertRemoteEvent("SetHitboxEnabled")



local HitboxService = {}
HitboxService.__index = HitboxService



export type HitboxService = {
	MaxHitBoxDuration: number, -- default cooldown timer for hitbox registration, should be instantiated on new()
	Instantiate : () -> thread, -- begins the HitboxService, returns the thread object it runs on
	Hitboxes : {[number]:{HitboxObject: BasePart, WeaponConfigurationName: string, Owner: Player}}, -- List of hitboxes to track and its associated weapon configuration name
	AddHitBox: (BasePart) -> (), -- Adds a BasePart instance to the Hitboxes array
	Waittime : number, -- The time between each hitbox detection
	HitPlayerDuration : number, -- How long before a detected player can be hit again by the same object
	HitPlayerRegistry : {[string]: {[BasePart] : number | boolean}}, -- Registry to track what players got hit by what. values should be an os.clock of how long it's been or falsy
	HitboxesOn: {[BasePart]: {TimeStamp: number | boolean, WeaponConfigurationName: string, Owner: Player}}, -- Which Hitboxes to check, values of TimeStamp are os.clock of how long it's been on or falsy
	IsCollidingWithHumanoidCharacter: (BasePart)  -> Model | boolean, -- Detects collisions with humanoid-containing characters, returns the character its hit or false
	HitPlayer : (string, any) -> (), -- Performs damage calculation
	Connections : {RBXScriptConnection}


}



-- Instantiates HitboxService class, expects (number)
function HitboxService.new(defaultCooldown: number, waittime : number, hitPlayerDuration : number)
	local self = setmetatable({}, HitboxService)
	self.MaxHitBoxDuration = defaultCooldown
	self.Hitboxes = {}
	self.HitboxesOn = {}
	self.Connections = {}
	self.HitPlayerRegistry = {}

	self.Waittime = waittime or 0.05
	self.HitPlayerDuration = hitPlayerDuration or 0.5




	return self
end

-- Adds a hitbox to the registry
function HitboxService:AddHitbox(part: BasePart, weaponConfigurationName : string, owner: Player)
	if self.Hitboxes[part] then warn("HitboxService: Hitbox already managed!"..part.Name) return end
	if not GlobalWeaponConfigTable[weaponConfigurationName] then warn("HitboxService: tried to register a hitbox for invalid weapon config name ".. weaponConfigurationName.."! Have you set up weapon configuration properly? See GlobalWeaponsConfigTable") end
	self.Hitboxes[part] = {HitboxObject = part, WeaponConfigurationName = weaponConfigurationName, Owner = owner}
end

-- Removes a hitbox from the registry
function HitboxService:RemoveHitbox(item: BasePart?)
	if item then
		self.Hitboxes[item] = nil
	end
end


function HitboxService:SetUpToolHitboxes(tool:Tool, player : Player)
	for i, v in pairs(getDescendantsOfType("BasePart", tool)) do
		self:AddHitbox(v, tool.Name, player)
		v.AncestryChanged:Connect(function(_, parent)
			if not parent then
				self:RemoveHitbox(v)
			end

		end)
	end
end


function HitboxService:IsCollidingWithHumanoidCharacter(part: BasePart, tool: Tool): Model | boolean

	local position = part.CFrame
	local size = part.Size
	local halfSize = size / 2

	local corners = {
		position * Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
		position * Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
		position * Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
		position * Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
		position * Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
		position * Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
		position * Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
		position * Vector3.new(halfSize.X, halfSize.Y, halfSize.Z)
	}

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = getDescendantsOfType("BasePart", tool) :: {Instance}
	table.insert(raycastParams.FilterDescendantsInstances, part)
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local center = position
	for _, corner in corners do
		local direction = (center - corner)

		local results = findAllPartsOnRay(corner, direction.Position, raycastParams) -- max 5-10 items
		if not results then return false end
		for _, result in pairs(results) do
			if result then
				local character = result.Parent
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoid then
					return character
				else
					table.insert(raycastParams.FilterDescendantsInstances, result)
				end
			end
		end
	end

	return false
end

function HitboxService:HitCharacter(char : Model, hitboxInfo: any)
	if not char:IsDescendantOf(workspace) then return end
	local player = char.Name
	if not self.HitPlayerRegistry[player] then
		self.HitPlayerRegistry[player] = {}
	end
	local part = hitboxInfo.HitboxObject
	local weaponConfigName = hitboxInfo.WeaponConfigurationName
	if self.HitPlayerRegistry[player][part] and (os.clock() - self.HitPlayerRegistry[player][part] > self.HitPlayerDuration ) then
		self.HitPlayerRegistry[player][part] = nil
	end
	if (not self.HitPlayerRegistry[player][part]) then
		self.HitPlayerRegistry[player][part] = os.clock()
		if char:FindFirstChild("Humanoid") then
			local weaponConfiguration = GlobalWeaponConfigTable[weaponConfigName]
			if not weaponConfiguration then warn("HitboxService: Tried to get the config of invalid weapon configuration name "..tostring(weaponConfigName))
			else
				char:FindFirstChild("Humanoid"):TakeDamage(weaponConfiguration.Damage)
			end
		end
	end
end

-- Instantiates the HitboxService instance. Should only be ran once and returns a Thread instance. To close or dispose of this instance, call task.cancel() on the returned Thread.
function HitboxService:InstantiateService()

	table.insert(self.Connections, SetHitboxEnabled.OnServerEvent:Connect(function(player: Player, hitboxObject: BasePart, enabled : boolean, associatedtool: Tool)
		if not player.Character then return end
		if hitboxObject:IsDescendantOf(player.Character) or hitboxObject:IsDescendantOf(player.Backpack) then
			if not self.HitboxesOn[hitboxObject] then
				self.HitboxesOn[hitboxObject] = {TimeStamp = false, WeaponConfigurationName = associatedtool.Name, Owner = player.Character}
			end
			if not self.Hitboxes[hitboxObject] then
				self:SetUpToolHitboxes(associatedtool, player)
			end
			if enabled then
				self.HitboxesOn[hitboxObject].TimeStamp = os.clock()
			else
				self.HitboxesOn[hitboxObject].TimeStamp = false
			end
		end
	end))

	return task.spawn(function()
		while true do
			task.wait(self.Waittime)
			for i, v in pairs(self.Hitboxes) do
				v.HitboxObject = v.HitboxObject
				if v.Owner and v.Owner.Character and self.HitboxesOn[v.HitboxObject] and self.HitboxesOn[v.HitboxObject].TimeStamp then
					local foundTool = v.Owner.Character:FindFirstChild(v.WeaponConfigurationName) or v.Owner.Backpack:FindFirstChild(v.WeaponConfigurationName)
					if not foundTool then continue end
					local collidingWithPlayer = self:IsCollidingWithHumanoidCharacter(v.HitboxObject, foundTool)
					local HitboxOnData = self.HitboxesOn[v.HitboxObject]
					if collidingWithPlayer and HitboxOnData.Owner and collidingWithPlayer ~= HitboxOnData.Owner then
						self:HitCharacter(collidingWithPlayer, v)
					end
				end
			end
			
			for i, v in pairs(self.HitboxesOn) do
				local WeaponConfigurationData = GlobalWeaponConfigTable[v.WeaponConfigurationName]
				if not v.TimeStamp or ((os.clock() - v.TimeStamp) > WeaponConfigurationData.MaxHitBoxDuration) then
					self.HitboxesOn[i] = nil
				end
			end
			
		end
	end)
end

return HitboxService


