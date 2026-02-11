-- Weapon-related effects library

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")


local WeaponFX = {}

local function PlaySoundAtPart(soundId, volume, parentPart)
	assert(typeof(parentPart) == "Instance" and parentPart:IsA("BasePart"), "parentPart must be a BasePart")
	assert(soundId ~= nil, "soundId is required")

	local idStr = tostring(soundId)
	if not string.find(idStr, "rbxassetid://") then
		idStr = "rbxassetid://" .. idStr
	end

	local sound = Instance.new("Sound")
	sound.SoundId = idStr
	sound.Volume = volume or 1
	sound.PlaybackSpeed = sound.PlaybackSpeed+ (math.random(90, 110)/100)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 80
	sound.Parent = parentPart

	sound:Play()
	local connection
	connection = sound.Ended:Connect(function()
		if connection then
			connection:Disconnect()
		end
		sound:Destroy()
	end)
	game:GetService("Debris"):AddItem(sound, 30)

	return sound
end

WeaponFX.ShockwaveEffect = function(bat: Tool)
	task.delay(0.1, function()
		local Character = bat.Parent
		if not Character then return end
		local HRP = Character:FindFirstChild("HumanoidRootPart")
		local duration = 2
		local Cf = HRP.CFrame + HRP.CFrame.lookVector * 3
		local radius = 2
		local shockwave = Instance.new("Part")
		local shockwaveMesh = Instance.new('SpecialMesh')
		shockwaveMesh.Parent = shockwave
		shockwaveMesh.MeshType = Enum.MeshType.Sphere
		shockwaveMesh.Scale =  Vector3.new(radius, radius, 0.5)
		shockwave.Anchored = true
		shockwave.CanCollide = false
		shockwave.Transparency = 0.5
		shockwave.Material = Enum.Material.ForceField
		shockwave.Color = Color3.fromRGB(255, 255, 255)
		shockwave.CFrame = Cf * CFrame.Angles(math.rad(0), 0, 0)
		shockwave.Parent = workspace

		

		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(shockwave, tweenInfo, {
			Size = Vector3.new(radius * 2, radius * 2, 0.2),
			Transparency = 1
		})
		local tween2 = TweenService:Create(shockwaveMesh, tweenInfo, {
			Scale = Vector3.new(radius * 2, radius * 2, 0.2),
		})
		tween:Play()
		tween2:Play()

		game:GetService("Debris"):AddItem(shockwave, duration + 0.1)
	end)
end

WeaponFX.BatTrailEffect = function (bat: Tool)
	task.spawn(function()
		local lifetime = 0.5
		local spawnRate = 500
		local spawnAccumulator = 0
		local amount = 100
		local Handle = bat:FindFirstChild("Contents"):FindFirstChild("Handle")
		local TrailFX = Handle:FindFirstChild("WeldParts"):FindFirstChild("TrailPart")
		local connection;
		PlaySoundAtPart("90646533794715", 0.5, Handle)

		connection = RunService.RenderStepped:Connect(function(dt)
			spawnAccumulator += dt * spawnRate
			if amount <= 0 then connection:Disconnect() end
			while spawnAccumulator >= 1 do
				spawnAccumulator -= 1
				amount -= 1


				local TrailClone = Instance.new("Part")
				TrailClone.Anchored = true
				TrailClone.CanCollide = false
				TrailClone.Material = Enum.Material.Neon
				TrailClone.BrickColor = BrickColor.new("Institutional white")
				TrailClone.Size = TrailFX.Size
				TrailClone.Transparency = 0.4

				local sliceMesh = Instance.new("SpecialMesh")
				sliceMesh.Scale = Vector3.new(0.2, 0.4, 15)
				sliceMesh.MeshType = Enum.MeshType.Sphere
				sliceMesh.Parent = TrailClone

				TrailClone.CFrame =
					TrailFX.CFrame * CFrame.new(0, Handle.Size.Y / 4, 0)

				TrailClone.Parent = workspace

				task.spawn(function()
					local t = 0
					while t < lifetime do
						t += task.wait()
						TrailClone.Transparency = t / lifetime
					end
					TrailClone:Destroy()
				end)
				
			end
		end)
	end)
end


return WeaponFX
