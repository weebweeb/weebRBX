local ItemHandler = require(game.ReplicatedStorage.Shared.ObjectService)
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local DeviceMaid = require(game.ReplicatedStorage.Packages:WaitForChild("AkoibotsPackages"):WaitForChild("DeviceMaid"))
local RunService = game:GetService("RunService")

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local currentDevice = DeviceMaid:GetPlatform()
local UI = player:WaitForChild("PlayerGui")
local GrabUI = UI:WaitForChild("PlayerUI").GrabItemFrame.GrabItem
local GrabUIMobile = UI:WaitForChild("PlayerUI"):WaitForChild("Frame"):WaitForChild("GrabButton")
local GrabUIMobileButton = GrabUIMobile:WaitForChild("GrabItem")
local GrabText = GrabUI.ImageLabel["$2"]  -- TextFrame
local carrying = false
local carryingObject = nil
local carryAnimID = "rbxassetid://140103089013713"
local maxItems = 4

local moneyUI = game.ReplicatedStorage.Assets.Misc.Countdown
local Animator 
local hightlightedObject
local highlight = nil
local cashtext = nil
local lastItem = nil
local allItems = {}

local carryAnimation = Instance.new("Animation")
carryAnimation.AnimationId = carryAnimID
local carryAnimTrack
local debounce = false
local PickupDistance = 8

local client = ItemHandler.Client.new({
	PoolSize = 32,
	InterpSpeed = 18,
	PickupDistance = PickupDistance,
})

function setupAnimation()
	char = player.Character
	Animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")

	carryAnimTrack = Animator:LoadAnimation(carryAnimation)
	carryAnimTrack.Looped = true
	carryAnimTrack.Priority = Enum.AnimationPriority.Movement
end

function enumerateCarriedItems(player)
	local playerBackpack = player.Backpack
	local playerCharacter = player.Character
	if not playerCharacter or not playerBackpack then return end
	local num = 0
	local enumerated = {}
	for _, item in ipairs(playerCharacter:GetChildren()) do
		if item:IsA("Tool") and not enumerated[item] then
			num += 1
		end
	end
	for _, item in ipairs(playerBackpack:GetChildren()) do
		if item:IsA("Tool") and not enumerated[item] then
			num += 1
		end
	end
	return num
end

player.CharacterAdded:Connect(function(char)
	setupAnimation()
end)

game.Workspace:WaitForChild(player.Name)
setupAnimation()


function pickItem()
	if debounce then return end
	local me = game.Players.LocalPlayer
	if not me then return end
	local char = me.Character
	if not (char and char.PrimaryPart) then return end
	

	if char:FindFirstChildOfClass("Tool") then
		DropItem()
		return
	end
	
	if enumerateCarriedItems(player) >= maxItems then return end

	local pos = char.PrimaryPart.Position
	local best, bestDist = nil, math.huge
	allItems = client:getAllItems()
	if not next(allItems) then return end
	for id, item in pairs(allItems) do
		if item.Position then
			local d = (pos - item.Position).Magnitude
			if d < bestDist then bestDist = d; best = item end
		end
	end
	if not best then return end
	debounce = true
	if best.Carryable == true and not best.Meta.StoreItem then
		client:tryPickup(best.Id)
		carrying = false
		carryingObject = nil
	else
		if (carrying and carryingObject) then
			client:toggleCarry(carryingObject, false)
			carrying = false
			carryingObject = nil
			carryAnimTrack:Stop()
			local hum = char:FindFirstChild("Humanoid")
			if hum then hum.JumpHeight = game.StarterPlayer.CharacterJumpHeight end
		else 
			carrying = client:toggleCarry(best.Id, true)
			if carrying then
				carryingObject = best.Id
				carryAnimTrack:Play()
				local hum = char:FindFirstChild("Humanoid")
				if hum then hum.JumpHeight = 0 end
			end
		end



	end
	debounce = false
end

function DropItem()
	if debounce then return end
	debounce = true
	local foundHeldItem
	if carrying and carryingObject and not char:FindFirstChildOfClass("Tool") then
		carrying = client:toggleCarry(carryingObject, false)
		carryingObject = nil
		carryAnimTrack:Stop()
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.JumpHeight = game.StarterPlayer.CharacterJumpHeight end
	else
		if not game.Workspace:FindFirstChild(player.Name) then return end
		local items = player.Character:GetChildren()
		for i, v in pairs(items) do
			if v:IsA("Tool") then
				foundHeldItem = v
				break end
		end
	end
	if foundHeldItem then
		if not foundHeldItem:GetAttribute("ItemId") then return end
		client:dropHeldItem(foundHeldItem:GetAttribute("ItemId"))
	end
	debounce = false
end

function Input(actionName, inputState, _inputObject)
	if actionName == "Pick Up Item" and inputState == Enum.UserInputState.Begin then
		pickItem()
	end
	if actionName == "Drop Item" and inputState == Enum.UserInputState.Begin then
		DropItem()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("Pick Up Item", Input, false, Enum.KeyCode.E)
ContextActionService:BindAction("Drop Item", Input, false, Enum.KeyCode.G)


-- ============================
-- MOBILE INPUT EXTENSION
-- ============================

local function ConnectInputFramework(button: TextButton, config)
	config = config or {}

	config.OnPress = function(i, t)
		if not carryingObject then
			pickItem()
		elseif char:FindFirstChildOfClass("Tool") then
			pickItem()
		else
			DropItem()
		end
	end

	local function ShouldActivate(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			return true
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			return true
		end
		return false
	end

	GrabUIMobileButton.InputBegan:Connect(function(input)
		if ShouldActivate(input) then
			if config.OnPress then
				config.OnPress(button, input)
			end
		end
	end)
end

ConnectInputFramework()



-- ============================
-- UI UPDATE LOOP (GRAB / DROP UI)
-- ============================


-- Returns nearest item using same logic as pickItem()
local function getNearestItem()
	local character = player.Character
	if not (character and character.PrimaryPart) then return nil end

	local pos = character.PrimaryPart.Position
	local best, bestDist = nil, math.huge
	allItems = client:getAllItems()
	if not next(allItems) then return end

	for id, item in pairs(allItems) do
		if item.Position and item.Instance and not item.Carried then
			local d = (pos - item.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = item
			end
		end
	end

	if best and best.Position and (best.Position - pos).Magnitude <= PickupDistance then
		return best
	end

	return nil
end


task.spawn(function()
	local t = 0

	local function deviceDependantUI()
		if currentDevice == "PC" then
			GrabUI.ImageLabel.ImageTransparency = 0
			GrabUI.ImageLabel.G.Visible = true
			GrabUI.ImageLabel["$2"].Visible = true
		else
			GrabUI.ImageLabel.ImageTransparency = 1
			GrabUI.ImageLabel.G.Visible = false
			GrabUI.ImageLabel["$2"].Visible = false
		end
		if currentDevice ~= "Mobile" then
			GrabUIMobile.Visible = false
		end
	end
	local nearestItem = getNearestItem()
	game:GetService("RunService").Heartbeat:Connect(function()
		t = t + 1
		if t % 300 == 1 then -- update items every 300 frames
			lastItem = nearestItem
			nearestItem = getNearestItem()
			currentDevice = DeviceMaid:GetPlatform()
			t = 0
		end

		if lastItem ~= nearestItem then
			if cashtext then cashtext:Destroy() end
			if highlight then highlight:Destroy() end
			if nearestItem then
				cashtext = moneyUI:Clone()
				cashtext.Parent = nearestItem.Instance
				cashtext.CountDown.Text = "$"..nearestItem.Meta.Value
				cashtext.CountDown.TextColor3 = Color3.new(0.384314, 1, 0)
				cashtext.CountDown.TextStrokeTransparency = 0.5
				cashtext.CountDown.TextStrokeColor3 = Color3.new(0, 0, 0)
				highlight = Instance.new("Highlight")
				highlight.FillTransparency = 1
				highlight.OutlineColor = Color3.new(1, 1, 1)
				highlight.OutlineTransparency = 0.5
				highlight.Parent = nearestItem.Instance
				highlight.Enabled = true
			end
		end

		if (carrying and carryingObject) or char:FindFirstChildOfClass("Tool") then
			GrabUI.Visible = true
			GrabText.Text = "Drop Item"
			GrabUIMobileButton.Text = "Drop Item"
			GrabUIMobile.Visible = true
			deviceDependantUI()
			return
		end

		if nearestItem then
			GrabUI.Visible = true
			GrabText.Text = "Grab Item"
			GrabUIMobileButton.Text = "Grab Item"
			GrabUIMobile.Visible = true
			deviceDependantUI()
		else
			GrabUIMobile.Visible = false
			GrabUI.Visible = false
		end
	end)
end)

