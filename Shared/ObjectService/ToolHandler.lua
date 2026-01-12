-- Handler for server-authoritative tool actions, should be used on client side and server side
-- Before initializing a tool on both the client and the server, both tools should have the attributes MaxCharges, Charges and WeightClass
-- Safe to require from both client and server.
-- On client it returns AbstractTool, on server it return ToolHandler. Expected use is to initialize a single ToolHandler instance to handle all tool operations
-- Before handing a tool off to a player, ToolHandler:CreateNewTool(tool: Tool) should be called on the server
-- See type definitions for more information
-- @a_lyve

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local DepleteChargeEvent = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DepleteCharge")
local RefreshInventoryEvent = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RefreshInventory")


local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local ToolHandler = {}
ToolHandler.__index = ToolHandler

local AbstractTool = {}
AbstractTool.__index = AbstractTool



-- Utilities


local function clamp(n: number, min: number, max: number): number
	return math.max(min, math.min(max, n))
end

local function getOrInitAttribute(tool: Tool, name: string, default)
	if tool:GetAttribute(name) == nil then
		tool:SetAttribute(name, default)
	end
	return tool:GetAttribute(name)
end

-- Constructor


export type ChargePreset = {
	OnBegin: ((self: any) -> ())?,
	OnTick: ((self: any, dt: number) -> ())?,
	OnEnd: ((self: any) -> ())?,
}

export type ToolHandler = {
	HandledTools: {AbstractTool},
	_DepleteConnection: RBXScriptConnection?, -- receive
	Consume: (tool: AbstractTool, num: number) ->(),
	SetCharges: (tool: AbstractTool, num: number) -> (),
}

export type AbstractTool = {
	Name: string,
	Player: Player?,
	Tool: Tool,
	WeightClass: string,
	MaxCharges: number,
	Preset: ChargePreset?,
	Charges: number,
	Active : boolean, -- Only used for continuous tools, sets the tool to active or inactive
	DepleteRate: number,
	DepleteConnection: RBXScriptConnection?, --send
	Begin: (self: any) -> (), -- Generic function for tool action
	End: (self: any) -> (),
}

function ToolHandler.new():ToolHandler
	local self: ToolHandler = setmetatable({}, ToolHandler)
	self.HandledTools = {}
	self._DepleteConnection = DepleteChargeEvent.OnServerEvent:Connect(function(player, passedtool:Tool)
		for _, tool in pairs(self.HandledTools) do

			if tool.Tool == passedtool then
				if tool.Preset.OnTick then
					tool.Active = not tool.Active
				else
					if tool.Charges > 0 then
						tool:Begin()
					end
				end
			end
		end
	end)
	return self
end

function AbstractTool.new(tool: Tool): AbstractTool
	assert(tool:IsA("Tool"), "AbstractTool requires a Tool")

	local self = setmetatable({}, AbstractTool)
	self.Tool = tool
	self.Active = false
	self.Preset = nil
	self.DepleteRate = self.DepleteRate or 1
	self.DepleteConnection = nil

	if IS_SERVER then
		self.MaxCharges = getOrInitAttribute(tool, "MaxCharges", 100)
		self.Charges = getOrInitAttribute(tool, "Charges", tool:GetAttribute("MaxCharges"))
	end

	if IS_CLIENT then
		self.Player = Players.LocalPlayer
	end

	return self
end


-- Server-side handler loop initialization
function ToolHandler:Initialize()
	if not IS_SERVER then return end
	task.spawn(function()

		while true do
			task.wait(1)
			local handledtools = self.HandledTools
			for _, tool in pairs(handledtools) do
				if tool.Preset and tool.Preset.OnTick and tool.Active then
					tool:Begin()
				end
			end
		end
	end)
end

-- Initializes a new tool for use within the handler
function ToolHandler:CreateNewTool(tool:Tool)
	self.HandledTools[tool] = AbstractTool.new(tool)
	return self.HandledTools[tool]
end

-- Server-side charge control

function AbstractTool:GetCharges(): number
	return self.Tool:GetAttribute("Charges")
end

function AbstractTool:GetMaxCharges(): number
	return self.Tool:GetAttribute("MaxCharges")
end

function ToolHandler:SetCharges(tool:AbstractTool, amount:number) --note: ToolHandler can't be seen by the client, so we place any authoritative action there
	assert(IS_SERVER, "SetCharges must be called on server")
	tool.Tool:SetAttribute("Charges", amount)
end


function ToolHandler:Consume(tool: AbstractTool, amount: number): boolean
	assert(IS_SERVER, "Consume must be called on server")

	local current = tool:GetCharges()
	if current < amount then
		return false
	end

	self:SetCharges(tool, current - amount)
	return true
end


-- Preset system


function AbstractTool:SetPreset(preset: ChargePreset)
	if not IS_SERVER then return end
	self.Preset = preset
	if preset.OnBegin then
		getOrInitAttribute(self.Tool, "DepleteMode", "Discrete")
	else
		getOrInitAttribute(self.Tool, "DepleteMode", "Continuous")
	end
end

function AbstractTool:Begin()
	if not IS_SERVER then return end

	if self.Preset and self.Preset.OnBegin then
		self.Preset.OnBegin(self)
	end

	if self.Preset and self.Preset.OnTick and self.Active then
		self.Preset.OnTick(self)
	end
	if self.Player then
		task.wait(0.25)
		RefreshInventoryEvent:FireClient(self.Player)
	end
end

function AbstractTool:End()
	if not IS_SERVER then return end
	if not self.Active then return end
	self.Active = false

	if self.Preset and self.Preset.OnEnd then
		self.Preset.OnEnd(self)
	end
end


-- Preset definitions


AbstractTool.Presets = {}

-- Continuous drain (flashlight, scanner, radio)
function AbstractTool.Presets.Continuous(drainPerSecond: number, onEmpty: (() -> ())?)
	return {
		OnTick = function(self: AbstractTool)
			if not ToolHandler:Consume(self, drainPerSecond) then
				self:End()
				if onEmpty then
					onEmpty()
				end
			end
		end
	}
end

-- Discrete consumption (ammo, charges, uses)
function AbstractTool.Presets.Discrete(cost: number, onFail: (() -> ())?)
	return {
		OnBegin = function(self: AbstractTool)
			if not ToolHandler:Consume(self, cost) then
				self:End()
				if onFail then
					onFail()
				end
			end
		end
	}
end


local function createAnimation(Animationid : string)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://"..Animationid
	return animation
end


-- Client-side animation helper (weight-based)

export type AnimationSet = {
	Light: Animation,
	Medium: Animation,
	Heavy: Animation,
	continueCarryLight: Animation,
	continueCarryMedium: Animation,
	continueCarryHeavy: Animation,
}

function AbstractTool:SetupCarryAnimations(animationSet: AnimationSet)
	assert(IS_CLIENT, "Animations must be set up on client")
	if not animationSet then print("AbstractTool: AnimationSet is nil, reverting to default animations for "..self.Tool.Name) end

	animationSet = animationSet or { -- defines the default animation set
		Light = createAnimation("81478126779315"),
		Medium = createAnimation("127822697179805"),
		Heavy = createAnimation("82541745369292"),
		continueCarryLight = createAnimation("109867808232799"),
		continueCarryMedium = createAnimation("140103089013713"),
		continueCarryHeavy = createAnimation("140103089013713"),
	}

	local tool = self.Tool
	local player = self.Player
	assert(player)

	local char = player.Character or player.CharacterAdded:Wait()
	local animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")

	local weight = tool:GetAttribute("WeightClass")
	assert(weight, "Tool missing WeightClass attribute")

	local beginAnim = animationSet[weight]
	local loopAnim = animationSet["continueCarry" .. weight]

	local beginTrack = animator:LoadAnimation(beginAnim)
	beginTrack.Looped = false
	beginTrack.Priority = Enum.AnimationPriority.Movement

	local loopTrack = animator:LoadAnimation(loopAnim)
	loopTrack.Looped = true
	loopTrack.Priority = Enum.AnimationPriority.Movement

	tool.Equipped:Connect(function()
		beginTrack:Play()
		loopTrack:Play()
	end)

	tool.Unequipped:Connect(function()
		loopTrack:Stop()
		if self.Active then
			self.Active = false
			DepleteChargeEvent:FireServer(tool)
		end
	end)

	tool.Destroying:Connect(function()
		beginTrack:Stop()
		loopTrack:Stop()
	end)
end

function AbstractTool:SetupRemotesClient()
	if not IS_CLIENT then return end
	local tool = self.Tool
	tool.Activated:Connect(function()
		self.Active = not self.Active
		DepleteChargeEvent:FireServer(tool)
		if self.Tool:GetAttribute("DepleteMode") and self.Tool:GetAttribute("DepleteMode") == "Continuous" then
			self.Active = self.Active
		else 
			self.Active = not self.Active
		end
	end)
end

function AbstractTool:InitializeClient()
	if not IS_CLIENT then return end
	self:SetupRemotesClient()
	self:SetupCarryAnimations()
end

if IS_SERVER then
	return ToolHandler
else
	return AbstractTool
end

