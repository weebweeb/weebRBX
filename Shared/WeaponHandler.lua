--a_lyve/weebweeb
--Example usage of WeaponClient

local camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponClient = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponClient"))
local WeaponFX = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("WeaponFX"))
local CameraShaker = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CameraShaker"))


local CamShakeManager = CameraShaker.new(camera)
local weaponAnimationProfile = WeaponClient.instantiateWeaponAnimationProfile()
local SetHitboxEnabled = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetHitboxEnabled")
local RequestFX = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponFXRequest")

local tool = script.Parent
local Hitbox = script.Parent:WaitForChild("Hitboxes"):WaitForChild("Hitbox")


weaponAnimationProfile.Idle = {
	ID = 124334820322263,
}

weaponAnimationProfile.Equip = {
	ID = 118321784645311,
}

weaponAnimationProfile.Attack1 = {
	ID = 89920978057865,
	MarkerInformation = weaponAnimationProfile.GenerateMarkerInformationfromMetaInfo(
		{
			{
				markerName = "startHitDetection",
				markerFunction = function()
					SetHitboxEnabled:FireServer(Hitbox, true, tool)
				end,
			},
			{
				markerName = "stopHitDetection",
				markerFunction = function()
					SetHitboxEnabled:FireServer(Hitbox, false, tool)

				end,
			}
		}
	)	
}

weaponAnimationProfile.Attack2 = {
	ID = 79176385631866,
	MarkerInformation = weaponAnimationProfile.GenerateMarkerInformationfromMetaInfo( 
		{
			{
				markerName = "startHitDetection",
				markerFunction = function()

					SetHitboxEnabled:FireServer(Hitbox, true, tool)
				end,
			},
			{
				markerName = "stopHitDetection",
				markerFunction = function()
					SetHitboxEnabled:FireServer(Hitbox, false, tool)

				end,
			}
		}

	)
}


local SetupWeapon = WeaponClient.new(game.Players.LocalPlayer, weaponAnimationProfile, script.Parent)

SetupWeapon:SetUpOnActivated(function()
	RequestFX:FireServer(tool, "BatTrailEffect")
	RequestFX:FireServer(tool, "ShockwaveEffect")
	WeaponFX["BatTrailEffect"](tool)
	WeaponFX["ShockwaveEffect"](tool)
	CamShakeManager:StartShake({
		Amplitude = 0.1,
		Frequency = 15,
		Duration = 0.5,
		Rotation = math.rad(2),
	})
	


end)

