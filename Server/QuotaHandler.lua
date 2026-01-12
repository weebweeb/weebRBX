--!strict
-- QuotaHandler
-- Server-only quota system
-- @a_lyve

local RunService = game:GetService("RunService")
local remotesFolder = game.ReplicatedStorage:WaitForChild("Remotes")

local QuotaHandler = {}
QuotaHandler.__index = QuotaHandler

-- Cubic growth function: q(n) = base * (n^3)
local BASE_QUOTA = 0

local function ensureRemote(name, remoteType)
	local r = remotesFolder:FindFirstChild(name)
	remoteType = remoteType or "RemoteEvent"
	if not r then
		r = Instance.new(remoteType)
		r.Name = name
		r.Parent = remotesFolder
	end
	return r
end

ensureRemote("QuotaUpdate", "RemoteEvent")
ensureRemote("QuotaSubtext", "RemoteEvent")



function QuotaHandler.new(initialMap: Instance, startLevel: number, Items: any)
	local self = setmetatable({}, QuotaHandler)

	self.CurrentMap = initialMap
	self.Level = startLevel
	self.Active = false
	self.Items = Items
	self.QuotaRemote = ensureRemote("QuotaUpdate", "RemoteEvent")
	self.QuotaSubtextChangeRemote = ensureRemote("QuotaSubtext", "RemoteEvent")

	self.Quota = BASE_QUOTA * (startLevel ^ 3)
	self.lastValue = 2
	self.TotalValue = 0
	self.ExtractPart = initialMap:WaitForChild("Extract")
	self.QuotaMet = false

	self._conn = nil

	return self
end

-- Scans for items inside the Extract area
function QuotaHandler:scanExtractZone(extract: BasePart, dictionary: table)
	local cf = extract.CFrame
	local size = extract.Size

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = game.Workspace:WaitForChild("Items"):GetChildren()

	local hits = workspace:GetPartBoundsInBox(cf, size, params)
	local total = 0

	for _, part in hits do
		local id = part:GetAttribute("ItemId") or part.Parent:GetAttribute("ItemId")
		if id and dictionary[id] then
			total += dictionary[id].Meta.Value or 0
		end
	end
	
	local QuotaMeter = extract:WaitForChild("Countdown")
	QuotaMeter.CountDown.Text = tostring(total).."\n----\n"..tostring(self.Quota)

	return total
end

-- Called every heartbeat while active
function QuotaHandler:Update()
	if not self.Active then return end

	self.TotalValue = self:scanExtractZone(self.ExtractPart, self.Items)
	if self.TotalValue ~= self.lastValue then
		self.lastValue = self.TotalValue
		self.QuotaSubtextChangeRemote:FireAllClients("QUOTA")
		self.QuotaRemote:FireAllClients("$"..tostring(self.Quota or 0))
	end

	if self.TotalValue >= self.Quota then
		self.QuotaMet = true
		self.ExtractPart.BrickColor = BrickColor.new("Neon green")
	else
		self.QuotaMet = false
		self.ExtractPart.BrickColor = BrickColor.new("Bright red")
	end
end

-- Stops active checking
function QuotaHandler:Stop()
	self.Active = false
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

-- Starts scanning on Heartbeat
function QuotaHandler:Start()
	if self.Active then return end
	self.Active = true

	self._conn = RunService.Heartbeat:Connect(function()
		self:Update()
	end)
end

-- Advances to next level & refreshes quota
function QuotaHandler:NextLevel(newMap: Instance, newLevel: number)
	self:Stop()

	self.CurrentMap = newMap
	self.Level = newLevel
	self.ExtractPart = newMap:WaitForChild("Extract")

	self.Quota = BASE_QUOTA * (newLevel ^ 3)
	self.lastValue = 2
	self.TotalValue = 0
	self.QuotaMet = false
	
	

	self:Start()
end

return QuotaHandler

