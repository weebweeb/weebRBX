-- Camera shaker module
-- a_lyve/weebweeb
--!strict


local RunService = game:GetService("RunService")

export type ShakeParams = {
	Amplitude: number,
	Frequency: number, 
	Duration: number,  
	Rotation: number?,   
}

export type CameraShake = {
	Start: (self: CameraShake) -> (),
	Stop: (self: CameraShake) -> (),
	Destroy: (self: CameraShake) -> (),
}

type InternalShake = {
	amplitude: number,
	frequency: number,
	duration: number,
	rotation: number,
	elapsed: number,
	seed: number,
}

local CameraShaker = {}
CameraShaker.__index = CameraShaker

function CameraShaker.new(camera: Camera)
	assert(camera, "CameraShaker requires a valid Camera")

	local self = setmetatable({}, CameraShaker)

	self._camera = camera
	self._shakes = {} :: { InternalShake }
	self._connection = nil :: RBXScriptConnection?
	self._baseCFrame = camera.CFrame

	return self
end

local function noise(t: number, seed: number): number
	return math.noise(t, seed) * 2
end

function CameraShaker:StartShake(params: ShakeParams)
	assert(params.Duration > 0, "Duration must be > 0")
	assert(params.Amplitude >= 0, "Amplitude must be >= 0")
	assert(params.Frequency > 0, "Frequency must be > 0")

	table.insert(self._shakes, {
		amplitude = params.Amplitude,
		frequency = params.Frequency,
		duration = params.Duration,
		rotation = params.Rotation or 0,
		elapsed = 0,
		seed = math.random(1, 10_000),
	})

	if not self._connection then
		self:Start()
	end
end

function CameraShaker:Start()
	if self._connection then
		return
	end


	self._connection = RunService.RenderStepped:Connect(function(dt)
		local posOffset = Vector3.zero
		local rotOffset = Vector3.zero

		for i = #self._shakes, 1, -1 do
			local shake : any = self._shakes[i]
			shake.elapsed += dt

			local alpha = shake.elapsed / shake.duration
			if alpha >= 1 then
				table.remove(self._shakes, i)
				continue
			end
			
			local fade = 1 - alpha
			local t = shake.elapsed * shake.frequency

			posOffset += Vector3.new(
				noise(t, shake.seed),
				noise(t, shake.seed + 1),
				noise(t, shake.seed + 2)
			) * shake.amplitude * fade

			if shake.rotation > 0 then
				rotOffset += Vector3.new(
					noise(t, shake.seed + 3),
					noise(t, shake.seed + 4),
					noise(t, shake.seed + 5)
				) * shake.rotation * fade
			end
		end
		self._baseCFrame = self._camera.CFrame


		self._camera.CFrame = self._baseCFrame * CFrame.new(posOffset) * CFrame.Angles(rotOffset.X, rotOffset.Y, rotOffset.Z)

		if #self._shakes == 0 then
			self:Stop()
		end
	end)
end

function CameraShaker:Stop()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	
	self._camera.CFrame = self._baseCFrame
end

function CameraShaker:Destroy()
	self:Stop()
	table.clear(self._shakes)
end

return CameraShaker

