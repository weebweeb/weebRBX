
-- Client-only renderer: receives room data from server and renders the minimap

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local minimapUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MinimapUpdate")
local minimapRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MinimapRequest")

local MinimapHandler = {}
MinimapHandler.__index = MinimapHandler
last = 0

-- ---------- Constructor / defaults (from your original, trimmed) ----------
function MinimapHandler.new(config)
	local self = setmetatable({}, MinimapHandler)

	-- required: expects a UI frame at config.UIFrame
	self.UIFrame = assert(config.UIFrame, "UIFrame required")

	self.Radius = config.Radius or 120
	self.UpdateRate = config.UpdateRate or 0.1
	self.ShowOrientation = config.ShowOrientation ~= false
	self.PlayerArrow = nil

	-- UI folders
	self.BlipFolder = Instance.new("Folder", self.UIFrame)
	self.BlipFolder.Name = "MinimapBlips"

	self.RoomOverlayFolder = self.UIFrame:FindFirstChild("RoomOverlays") or (function()
		local f = Instance.new("Folder", self.UIFrame)
		f.Name = "RoomOverlays"
		return f
	end)()

	-- state
	self.Rooms = {}            -- array of received rooms: {Name, Center(Vector3), Size(Vector3), IsCorridor, CFrame}
	self.ExploredRooms = {}    -- set keyed by room.Name
	self._lastUpdate = 0
	self.RenderVersion = -1

	return self
end

-- ---------- Utilities (kept from original) ----------
function MinimapHandler:WorldToMap(worldPos, originCF)
	local rel = originCF:PointToObjectSpace(worldPos)
	local ratio = 0.5 / self.Radius
	local x = rel.X * ratio
	local y = rel.Z * ratio * -1
	return x, y
end

function MinimapHandler:CreateBlipFromPart(part)
	local dot = Instance.new("Frame")
	local px = math.clamp(6 * (part.Size.X/4), 4, 48)
	local py = math.clamp(6 * (part.Size.Z/4), 4, 48)
	dot.Size = UDim2.fromOffset(px, py)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = Color3.new(1,1,1)
	dot.BorderSizePixel = 0
	dot.ZIndex = 10
	dot.Parent = self.BlipFolder
	return dot
end

-- ---------- Receive server data ----------
-- When server fires MinimapUpdate, update local cache
minimapUpdate.OnClientEvent:Connect(function(roomList, version)
	-- roomList is array of tables: {Name, Center(Vector3), Size(Vector3), IsCorridor, CFrame}
	local handler = _G.__MinimapHandlerInstance
	if handler then
		handler.Rooms = roomList or {}
		handler.RenderVersion = version or handler.RenderVersion
	end
end)

-- ---------- UI render ----------
function MinimapHandler:RenderRooms(originCF)
	self.BlipFolder:ClearAllChildren()
	for _, c in ipairs(self.RoomOverlayFolder:GetChildren()) do c:Destroy() end

	local originPos = originCF.Position

	local minimapFrame = self.UIFrame
	local abs = minimapFrame.AbsoluteSize
	local ar = abs.X / abs.Y

	local mapRenderW, mapRenderH
	if ar > 1 then
		mapRenderH = abs.Y
		mapRenderW = abs.Y
	else
		mapRenderW = abs.X
		mapRenderH = abs.X
	end

	local normX = mapRenderW / abs.X
	local normY = mapRenderH / abs.Y

	for _, room in ipairs(self.Rooms) do
		if room and room.Center then
			if self:IsPlayerInsideRoom(room, originPos) then
				self.ExploredRooms[room.Name] = true
			end
		end
	end

	for _, room in ipairs(self.Rooms) do
		local rx, ry = self:WorldToMap(room.Center, originCF)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = room.IsCorridor and Color3.fromRGB(0,229,255) or Color3.fromRGB(50,100,200)
		frame.Parent = self.RoomOverlayFolder

		if not self.ExploredRooms[room.Name] and not room.IsCorridor then
			frame.Size = UDim2.fromOffset(18, 18)
			frame.BackgroundTransparency = 0.2
			local t = Instance.new("TextLabel", frame)
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Size = UDim2.new(1,0,1,0)
			t.BackgroundTransparency = 1
			t.Text = "?"
			t.TextScaled = true
			t.TextColor3 = Color3.new(1,1,1)
		else
			local sx = math.clamp(room.Size.X / self.Radius * 0.5, 0.01, 1)
			local sy = math.clamp(room.Size.Z / self.Radius * 0.5, 0.01, 1)

			-- <<<< Aspect ratio adjusted size
			frame.Size = UDim2.new(sx * normX, 0, sy * normY, 0)
			frame.BackgroundTransparency = 0.6
		end

		if self.ShowOrientation and room.CFrame then
			local roomDir = room.CFrame.LookVector
			local rawAngle = math.atan2(roomDir.X, roomDir.Z)
			local playerAngle = math.atan2(originCF.LookVector.X, originCF.LookVector.Z)
			frame.Rotation = math.deg(rawAngle - playerAngle)
		end

		-- <<<< Aspect ratio–corrected position
		local px = 0.5 + rx * normX
		local py = 0.5 + ry * normY
		frame.Position = UDim2.new(px, 0, py, 0)
	end
end


function MinimapHandler:DrawPlayerArrow(playerCF)
	-- playerCF = player's CFrame

	-- Create container on first run
	if not self.PlayerArrow then
		local container = Instance.new("Frame")
		container.BackgroundTransparency = 1
		container.Size = UDim2.fromOffset(20, 20)
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.Name = "PlayerArrow"
		container.Parent = self.UIFrame

		-- Create the squares
		local function makeSquare(name)
			local f = Instance.new("Frame")
			f.Name = name
			f.BackgroundColor3 = Color3.new(0, 0.94902, 1)
			f.Size = UDim2.fromOffset(6, 6)
			f.BorderSizePixel = 0
			f.Parent = container
			return f
		end

		self.PlayerArrow = container
		self.PlayerArrowSquares = {
			Head = makeSquare("Head"),
			Left = makeSquare("Left"),
			Center = makeSquare("Center"),
			Right = makeSquare("Right"),
		}
	end

	self.PlayerArrow.Position = UDim2.new(0.5, 0, 0.5, 0)


	---------------------------------------------------------------------
	-- LAYOUT
	---------------------------------------------------------------------
	local squares = self.PlayerArrowSquares
	local headOffset = Vector2.new(0, 3)
	local rowOffset = 4

	squares.Head.Position = UDim2.fromOffset(
		self.PlayerArrow.AbsoluteSize.X/2 - squares.Head.AbsoluteSize.X/2,
		self.PlayerArrow.AbsoluteSize.Y/2 + 5
	)

	squares.Center.Position = UDim2.fromOffset(
		self.PlayerArrow.AbsoluteSize.X/2 - squares.Center.AbsoluteSize.X/2,
		self.PlayerArrow.AbsoluteSize.Y/2
	)

	squares.Left.Position = UDim2.fromOffset(
		self.PlayerArrow.AbsoluteSize.X/2 - squares.Center.AbsoluteSize.X/2 - rowOffset,
		self.PlayerArrow.AbsoluteSize.Y/2
	)

	squares.Right.Position = UDim2.fromOffset(
		self.PlayerArrow.AbsoluteSize.X/2 - squares.Center.AbsoluteSize.X/2 + rowOffset,
		self.PlayerArrow.AbsoluteSize.Y/2
	)
end

function MinimapHandler:IsPlayerInsideRoom(room, pos)
	local center = room.Center
	local size = (room.Size and Vector3.new(room.Size.X, room.Size.Y, room.Size.Z)) or room.Size
	-- size is Vector3: we used Vector3 on server. If it's Vector3, use X/Z.
	local halfX = (room.Size and room.Size.X) and (room.Size.X * 0.5) or (room.Size.x and room.Size.x * 0.5) or (self.Radius * 0.5)
	local halfZ = (room.Size and room.Size.Z) and (room.Size.Z * 0.5) or (room.Size.z and room.Size.z * 0.5) or (self.Radius * 0.5)

	return math.abs(pos.X - room.Center.X) <= halfX and math.abs(pos.Z - room.Center.Z) <= halfZ
end

-- ---------- Update / heartbeat ----------
function MinimapHandler:Update(dt)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	self._lastUpdate = self._lastUpdate + dt
	if self._lastUpdate < self.UpdateRate then return end
	self._lastUpdate = 0

	-- render
	task.wait()

	self:RenderRooms(hrp.CFrame)
	self:DrawPlayerArrow(hrp.CFrame)
end

-- ---------- Start ----------
function MinimapHandler:Start()
	-- request initial data from server (synchronous call)
	local ok, rooms, version = pcall(function()
		return minimapRequest:InvokeServer()
	end)

	if ok and rooms then
		self.Rooms = rooms
		self.RenderVersion = version or self.RenderVersion
	end

	-- store instance pointer for OnClientEvent callback
	_G.__MinimapHandlerInstance = self
	local last = tick()
	RunService.RenderStepped:Connect(function()
		local now = tick()
		local dt = now - last
		last = now
		self._lastUpdate = self._lastUpdate + dt
		if self._lastUpdate >= self.UpdateRate then
			self._lastUpdate = 0
			self:Update(self.UpdateRate)
			
		end
	end)
end

-- ---------- Export factory ----------
-- Usage: local m = require(...).new({UIFrame = script.Parent.MinimapUI}); m:Start()
return MinimapHandler