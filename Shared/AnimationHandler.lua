-- AnimationHandler
-- Basic class which handles animations
-- a_lyve/weebweeb
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ManagedAnimation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ManagedAnimation"))
local AnimationHandler = {}
AnimationHandler.__index = AnimationHandler


export type AnimationHandler = {
	Animator: Animator | AnimationController | Humanoid,
	CurrentTrack : ManagedAnimation.ManagedAnimation?,
	LoadedAnimations: {[any]: ManagedAnimation.ManagedAnimation},
	BulkLoadAnimations : ({[string]: { ID: string | number, MarkerInformation: {ManagedAnimation.MarkerInformation}}}) -> (),
	LoadAnimation : (number | string, string | number?) -> (),
	ManagedAnimation : ManagedAnimation.ManagedAnimation
	

}


function AnimationHandler.new(animationController: Animator | AnimationController | Humanoid)
	local self = setmetatable({}, AnimationHandler)
	self.LoadedAnimations = {}
	self.Animator = animationController
	self.CurrentTrack = nil

	return self
end

function AnimationHandler:LoadAnimation(animationId: number | string, name: string? | number?, MarkerInfo : {ManagedAnimation.MarkerInformation})
	local animationKey: string | number = name or animationId
	self.LoadedAnimations[animationKey] = ManagedAnimation.new(animationId, self.Animator, MarkerInfo)
end

function AnimationHandler:BulkLoadAnimations(animationIds: {[string]: { ID: string | number, MarkerInformation: {ManagedAnimation.MarkerInformation}}})
	for i, v in pairs(animationIds) do
		self:LoadAnimation(v.ID, i, v.MarkerInformation)
	end
end

function AnimationHandler:PlayAnimation(animIdOrName: string | number)
	self.LoadedAnimations[animIdOrName].AnimationTrack:Play()
end

function AnimationHandler:StopAnimation(animIdOrName: string | number)
	self.LoadedAnimations[animIdOrName].AnimationTrack:Stop()
end

function AnimationHandler:StopAllAnimations()
	for i, v in pairs(self.LoadedAnimations) do
		self:StopAnimation(i)
	end
end



return AnimationHandler






















-- a_lyve/weebweeb