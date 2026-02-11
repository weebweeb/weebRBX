-- ManagedAnimation
-- Base class which abstracts the creation of animations for ease of use
-- a_lyve/weebweeb

local ManagedAnimation = {}
ManagedAnimation.__index = ManagedAnimation

local MarkerInformation = {}
MarkerInformation.__index = ManagedAnimation

export type MarkerInformation = {
	Name: string,
	Function: () -> ()
}

export type ManagedAnimation = {
	Animator: Animator | AnimationController | Humanoid,
	AnimationTrack : AnimationTrack,
	Animation : Animation | AnimationClip,
	Name : string,
	SetupMarker: () -> RBXScriptSignal,
	Markers: {[string | number]: RBXScriptSignal}

}

-- Internal MarkerInformation class
function MarkerInformation.new(name : string, funct: () -> ())
	local self = setmetatable({}, MarkerInformation)
	self.Name = name
	self.Function = funct
	return self
end

-- Initialize a MarkerInformation class instance for use publicly
function ManagedAnimation.ConstructMarkerInformation(name: string, funct: () -> ())
	return MarkerInformation.new(name, funct)
end

-- Sets up marker information manually for use with GetMarkerReachedSignal
function ManagedAnimation:SetupMarker(name : string, lambda:() -> ())
	if self.Markers[name] then self.Markers:Disconnect() end
	self.Markers[name] = self.AnimationTrack:GetMarkerReachedSignal(name):Connect(lambda)
	return self.Markers[name]
end

-- Sets up marker information for use with GetMarkerReachedSignal in batches, expects {MarkerInformation}
function ManagedAnimation:SetupBatchMarkerInformation(batch:{MarkerInformation})
	for i, v in pairs(batch) do
		self:SetupMarker(v.Name, v.Function)
	end
end

-- Initializes a new ManagedAnimation instance
function ManagedAnimation.new(animationId: number | string, animator : Animator | AnimationController | Humanoid, MarkerInfo : {MarkerInformation}?)
	local self = setmetatable({}, ManagedAnimation)
	
	self.Animation = Instance.new("Animation")
	self.Name = tostring(animationId)
	self.Animation.AnimationId = "rbxassetid://"..tostring(animationId)
	self.Animator = animator
	self.AnimationTrack = self.Animator:LoadAnimation(self.Animation)
	self.Markers = {}
	
	if MarkerInfo then
		for i, v in pairs(MarkerInfo) do
			self:SetupMarker(v.Name, v.Function)
		end
	end


	return self
end

return ManagedAnimation
