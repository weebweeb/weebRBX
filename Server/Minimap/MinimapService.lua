-- Publishes compact room metadata via ReplicatedStorage.MinimapUpdate
-- @a_lyve

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- Ensure RemoteEvent/Function exist
local minimapUpdate = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("MinimapUpdate")
if not minimapUpdate then
	minimapUpdate = Instance.new("RemoteEvent")
	minimapUpdate.Name = "MinimapUpdate"
	minimapUpdate.Parent = ReplicatedStorage
end

local minimapRequest = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("MinimapRequest")
if not minimapRequest then
	minimapRequest = Instance.new("RemoteFunction")
	minimapRequest.Name = "MinimapRequest"
	minimapRequest.Parent = ReplicatedStorage
end

local MinimapServerInstance = nil

local MinimapServer = {}
MinimapServer.__index = MinimapServer

-- ---------- Config ----------
MinimapServer.MIN_SIZE = Vector3.new(0, 10, 0)
MinimapServer.SCAN_INTERVAL = 2.0
MinimapServer.WallAdjTolerance = 3
MinimapServer.WallAngleTolerance = 30
MinimapServer.CorridorWidthThreshold = 16
MinimapServer.MaxRoomSize = Vector2.new(0.0001, 0.0001) -- depreciated
MinimapServer.SplitMinParts = 5 -- depreciated, no longer needed

-- ---------- Constructor ----------
function MinimapServer.new(objectsFolder)
	local self = setmetatable({}, MinimapServer)
	self.ObjectsFolder = objectsFolder or Workspace
	self._accum = 0
	self.Rooms = {}    -- cached obb tables
	self.Version = 0
	return self
end

-- ---------- Utilities ----------
local function degToRad(d) return d * math.pi / 180 end
local function radToDeg(r) return r * 180 / math.pi end

-- compute PCA frame 
local function computePCAFrame(parts)
	local meanX, meanZ = 0, 0
	local n = 0
	for _, p in ipairs(parts) do
		meanX = meanX + p.Position.X
		meanZ = meanZ + p.Position.Z
		n = n + 1
	end
	if n == 0 then return CFrame.new(), Vector3.new(0,0,0) end
	meanX = meanX / n
	meanZ = meanZ / n

	local Vxx, Vxz, Szz = 0, 0, 0
	for _, p in ipairs(parts) do
		local x = p.Position.X - meanX
		local z = p.Position.Z - meanZ
		Vxx = Vxx + x * x
		Vxz = Vxz + x * z
		Szz = Szz + z * z
	end

	local trace = Vxx + Szz
	local det = Vxx * Szz - Vxz * Vxz
	local temp = 0
	if (trace * trace) * 0.25 - det >= 0 then
		temp = math.sqrt((trace * trace) * 0.25 - det)
	else
		temp = 0
	end
	local lambda1 = trace * 0.5 + temp

	local vx, vz
	if math.abs(Vxz) > 1e-6 then
		vx = lambda1 - Szz
		vz = Vxz
	else
		if Vxx >= Szz then vx, vz = 1, 0 else vx, vz = 0, 1 end
	end
	local len = math.sqrt(vx*vx + vz*vz)
	if len < 1e-6 then vx, vz = 1, 0; len = 1 end
	vx, vz = vx/len, vz/len

	local forward = Vector3.new(vx, 0, vz)
	local cf = CFrame.lookAt(Vector3.new(0,0,0), forward, Vector3.new(0,1,0))
	return cf, forward.Unit, Vector3.new(meanX, 0, meanZ)
end

-- compute OBB from parts
local function computeOBB(parts)
	if #parts == 0 then return nil end

  	local pcaFrame, forward, mean2D = computePCAFrame(parts)
	local inv = pcaFrame:Inverse()

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		local corners = {
			Vector3.new(-half.X, -half.Y, -half.Z),
			Vector3.new(-half.X, -half.Y,  half.Z),
			Vector3.new(-half.X,  half.Y, -half.Z),
			Vector3.new(-half.X,  half.Y,  half.Z),
			Vector3.new( half.X, -half.Y, -half.Z),
			Vector3.new( half.X, -half.Y,  half.Z),
			Vector3.new( half.X,  half.Y, -half.Z),
			Vector3.new( half.X,  half.Y,  half.Z),
		}
		for _, c in ipairs(corners) do
			local world = part.CFrame:PointToWorldSpace(c)
			local localPoint = inv:PointToWorldSpace(world)
			minX = math.min(minX, localPoint.X)
			minY = math.min(minY, localPoint.Y)
			minZ = math.min(minZ, localPoint.Z)
			maxX = math.max(maxX, localPoint.X)
			maxY = math.max(maxY, localPoint.Y)
			maxZ = math.max(maxZ, localPoint.Z)
		end
	end

	if minX == math.huge then return nil end

	local centerLocal = Vector3.new((minX + maxX)/2, (minY + maxY)/2, (minZ + maxZ)/2)
	local halfSize = Vector3.new((maxX - minX)/2, (maxY - minY)/2, (maxZ - minZ)/2)
	local worldCenter = pcaFrame:PointToWorldSpace(centerLocal)
	local right = forward:Cross(Vector3.new(0,1,0))
	local forward = forward.Unit

	local up = Vector3.new(0,1,0)
	if math.abs(forward:Dot(up)) > 0.95 then
		up = Vector3.new(1,0,0) -- choose alternate axis if too parallel
	end

	local right = forward:Cross(up).Unit
	up = right:Cross(forward).Unit
	
	local calculatedCFrame = CFrame.fromMatrix(worldCenter, right, up, forward)
	
	local calculatedLookVector = calculatedCFrame.LookVector or Vector3.new(1,0,0)
	
	--if #parts == 1 then calculatedLookVector = parts[1].CFrame.LookVector or calculatedLookVector print(parts[1].CFrame.LookVector) end
	
	if #parts == 1 then
		local p = parts[1]
		return {
			Center = worldCenter,
			CFrame = calculatedCFrame,               
			Size = halfSize*2,                     
			calculatedLookVector = p.CFrame.LookVector,
			Parts = parts,
		}
	end

	return {
		Center = worldCenter,
		--CFrame = CFrame.new(worldCenter) * pcaFrame,
		CFrame = calculatedCFrame,
		calculatedLookVector = calculatedLookVector,
		Size = halfSize * 2,
		Parts = parts,
	}
end

-- axis-aligned overlap (kept in server if needed)
local function aabbOverlapParts(aPos, aSize, bPos, bSize)
	return math.abs(aPos.X - bPos.X) * 2 < (aSize.X + bSize.X)
		and math.abs(aPos.Y - bPos.Y) * 2 < (aSize.Y + bSize.Y)
		and math.abs(aPos.Z - bPos.Z) * 2 < (aSize.Z + bSize.Z)
end

-- ---------- Spatial gather on server ----------
local function gatherParts(objectsFolder, minSize)
	local out = {}
	for _, p in ipairs(objectsFolder:GetDescendants()) do
		if p:IsA("BasePart") then
			local s = p.Size
			if not s then continue end
			if s.X < minSize.X or s.Y < minSize.Y or s.Z < minSize.Z then
				continue
			end
			if p.Transparency and p.Transparency > 0.8 then continue end

			if p.Locked == false then
				table.insert(out, p)
			end
		end
	end
	return out
end

-- ---------- Graph building & clustering ----------
local function wallsTouch(a, b, tol, angleTol)
	local apos, bpos = a.Position, b.Position
	local dx = math.abs(apos.X - bpos.X)
	local dz = math.abs(apos.Z - bpos.Z)

	local sa, sb = a.Size, b.Size
	tol = tol or 5
	local distOK = dx <= (sa.X + sb.X)/2 + tol and dz <= (sa.Z + sb.Z)/2 + tol

	local aheadA = a.CFrame.LookVector
	local aheadB = b.CFrame.LookVector
	local dot = (aheadA.X * aheadB.X + aheadA.Z * aheadB.Z)
	if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
	local angle = math.deg(math.acos(math.abs(dot)))
	angleTol = angleTol or 10
	local angleOK = angle <= angleTol

	return distOK and angleOK
end

local function BuildWallGraph(parts, self)
	local graph = {}
	for i, p in ipairs(parts) do graph[p] = {} end
	for i = 1, #parts do
		local a = parts[i]
		for j = i+1, #parts do
			local b = parts[j]
			if wallsTouch(a, b, self.WallAdjTolerance, self.WallAngleTolerance) then
				table.insert(graph[a], b)
				table.insert(graph[b], a)
			end
		end
	end
	return graph
end

local function FloodFillClusters(graph)
	local clusters, visited = {}, {}
	for node, _ in pairs(graph) do
		if not visited[node] then
			local queue = {node}
			visited[node] = true
			local cluster = {}
			while #queue > 0 do
				local cur = table.remove(queue, 1)
				table.insert(cluster, cur)
				for _, nb in ipairs(graph[cur] or {}) do
					if not visited[nb] then
						visited[nb] = true
						table.insert(queue, nb)
					end
				end
			end
			table.insert(clusters, cluster)
		end
	end
	return clusters
end

local function IsCorridor(obb, threshold)
	threshold = threshold or MinimapServer.CorridorWidthThreshold
	local width = math.min(obb.Size.X, obb.Size.Z)
	return width < threshold
end

-- split cluster
 function SplitClusterIfOversized(cluster, self)
	local rooms = {}
	local function recurse(parts)
		if #parts == 0 then return end
		local obb = computeOBB(parts)
		if not obb then return end

		local tooWide = obb.Size.X > self.MaxRoomSize.X
		local tooLong = obb.Size.Z > self.MaxRoomSize.Y
		if (not tooWide) and (not tooLong) then
			table.insert(rooms, parts)
			return
		end

		if #parts <= self.SplitMinParts then
			table.insert(rooms, parts)
			return
		end

		local longestAxis = (obb.Size.X >= obb.Size.Z) and "X" or "Z"
		local inv = obb.CFrame:Inverse()
		table.sort(parts, function(a,b)
			local la = inv:PointToObjectSpace(a.Position)
			local lb = inv:PointToObjectSpace(b.Position)
			if longestAxis == "X" then return la.X < lb.X else return la.Z < lb.Z end
		end)

		local mid = math.floor(#parts/2)
		local left, right = {}, {}
		for i=1,#parts do
			if i <= mid then table.insert(left, parts[i]) else table.insert(right, parts[i]) end
		end

		recurse(left)
		recurse(right)
	end
	recurse(cluster)
	return rooms
end

-- make walls from room data
function BuildWallsFromRooms(cluster, self)
	local rooms = {}
	local function recurse(parts)
		if #parts == 0 then return end
		local obb = computeOBB(parts)
		if not obb then return end

		local tooWide = obb.Size.X > self.MaxRoomSize.X
		local tooLong = obb.Size.Z > self.MaxRoomSize.Y
		if (not tooWide) and (not tooLong) then
			table.insert(rooms, parts)
			return
		end

		if #parts <= 1 then
			table.insert(rooms, parts)
			return
		end

		local longestAxis = (obb.Size.X >= obb.Size.Z) and "X" or "Z"
		local inv = obb.CFrame:Inverse()
		table.sort(parts, function(a,b)
			local la = inv:PointToObjectSpace(a.Position)
			local lb = inv:PointToObjectSpace(b.Position)
			if longestAxis == "X" then return la.X < lb.X else return la.Z < lb.Z end
		end)

		local mid = math.floor(#parts/2)
		local left, right = {}, {}
		for i=1,#parts do
			if i <= mid then table.insert(left, parts[i]) else table.insert(right, parts[i]) end
		end

		recurse(left)
		recurse(right)
	end
	recurse(cluster)
	return rooms
end

-----------------------------------------------------------------------
-- Detect rooms by looking for open pockets of space (no walls)
-----------------------------------------------------------------------
local function DetectEmptySpaceRooms(walls, cellSize)
	cellSize = cellSize or 8

	-- 1. Build global AABB around walls
	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge

	for _, w in ipairs(walls) do
		local c = w.Position
		local s = w.Size * 0.5
		minX = math.min(minX, c.X - s.X)
		maxX = math.max(maxX, c.X + s.X)
		minZ = math.min(minZ, c.Z - s.Z)
		maxZ = math.max(maxZ, c.Z + s.Z)
	end
	if minX == math.huge then return {} end

	-- Expand slightly inward so the border test is reliable
	local PAD = cellSize * 2
	minX += PAD
	maxX -= PAD
	minZ += PAD
	maxZ -= PAD

	local function toCell(x)
		return math.floor(x / cellSize)
	end
	local gx0, gx1 = toCell(minX), toCell(maxX)
	local gz0, gz1 = toCell(minZ), toCell(maxZ)

	-- 2. Grid initialization
	local grid = {}
	for gx = gx0, gx1 do
		grid[gx] = {}
		for gz = gz0, gz1 do
			grid[gx][gz] = false
		end
	end

	-- 3. Stamp walls into grid
	for _, w in ipairs(walls) do
		local c = w.Position
		local s = w.Size * 0.5
		local minGX = toCell(c.X - s.X)
		local maxGX = toCell(c.X + s.X)
		local minGZ = toCell(c.Z - s.Z)
		local maxGZ = toCell(c.Z + s.Z)

		for gx = minGX, maxGX do
			for gz = minGZ, maxGZ do
				if grid[gx] and grid[gx][gz] ~= nil then
					grid[gx][gz] = true
				end
			end
		end
	end

	-- 4. Flood-fill open spaces
	local visited = {}
	local clusters = {}
	local dirs = { {1,0},{-1,0},{0,1},{0,-1} }

	local function floodFill(startGX, startGZ)
		local touchesBorder = false
		local cells = {}
		local queue = {{startGX, startGZ}}
		local key = startGX.."_"..startGZ
		visited[key] = true

		while #queue > 0 do
			local n = table.remove(queue,1)
			local gx, gz = n[1], n[2]

			-- Detect if touching boundary - outside
			if gx == gx0 or gx == gx1 or gz == gz0 or gz == gz1 then
				touchesBorder = true
			end

			table.insert(cells, {gx, gz})

			for _,d in ipairs(dirs) do
				local nx, nz = gx+d[1], gz+d[2]
				local key2 = nx.."_"..nz

				if grid[nx] and grid[nx][nz] ~= nil then
					if not grid[nx][nz] and not visited[key2] then
						visited[key2] = true
						table.insert(queue, {nx,nz})
					end
				end
			end
		end

		return cells, touchesBorder
	end

	for gx = gx0, gx1 do
		for gz = gz0, gz1 do
			if not grid[gx][gz] then
				local key = gx.."_"..gz
				if not visited[key] then
					local cluster, touchesBorder = floodFill(gx, gz)
					if #cluster > 0 then
						table.insert(clusters, {cells = cluster, border = touchesBorder})
					end
				end
			end
		end
	end

	-- 5. Convert interior clusters - OBB rooms
	local roomOBBs = {}

	-- thresholds for rejecting outdoor spaces
	local MAX_CELL_COUNT = 100    -- reject huge open fields
	local MAX_OBB_SIZE   = 50     -- OBB max axis length

	for _, entry in ipairs(clusters) do
		local cluster = entry.cells
		local touchesBorder = entry.border

		-- Rule 1: touching border - considered outside
		if touchesBorder then
			continue
		end

		-- Rule 2: too many cells - outside / too big
		if #cluster > MAX_CELL_COUNT then
			continue
		end

		-- Convert cells - fake parts
		local fakeParts = {}
		for _, cell in ipairs(cluster) do
			local gx, gz = cell[1], cell[2]
			local wx = gx * cellSize
			local wz = gz * cellSize
			local fake = {
				Position = Vector3.new(wx, 0, wz),
				Size = Vector3.new(cellSize, 1, cellSize),
				CFrame = CFrame.new(wx, 0, wz)
			}
			table.insert(fakeParts, fake)
		end

		local obb = computeOBB(fakeParts)
		if obb then
			-- Rule 3: OBB is too large - outside terrain
			if math.max(obb.Size.X, obb.Size.Z) > MAX_OBB_SIZE then
				continue
			end

			obb.IsCorridor = false
			table.insert(roomOBBs, obb)
		end
	end

	return roomOBBs
end






-- ---------- Full server-side detection pipeline ----------
function MinimapServer:ScanAndBuild()
	local parts = gatherParts(self.ObjectsFolder, self.MIN_SIZE)

	local walls = {}
	for _, p in ipairs(parts) do
		if p.Size.X > 1 or p.Size.Z > 1 then
			table.insert(walls, p)
		end
	end

	local graph = BuildWallGraph(walls, self)
	local rawClusters = FloodFillClusters(graph)
	
	

	local finalClusters = {}
	for _, cluster in ipairs(rawClusters) do
		local splits = BuildWallsFromRooms(cluster, self)
		for _, s in ipairs(splits) do table.insert(finalClusters, s) end
	end
	
	--for _, cluster in ipairs(rawClusters) do
	--	local splits = SplitClusterIfOversized(cluster, self)
	--	for _, s in ipairs(splits) do table.insert(finalClusters, s) end
	--end

	local rooms = {}
	for i, cluster in ipairs(finalClusters) do
		local obb = computeOBB(cluster)
		if obb then
			obb.IsCorridor = IsCorridor(obb, self.CorridorWidthThreshold)
			obb.Name = ("Room_%d"):format(i)
			rooms[#rooms+1] = obb
		end
	end
	
	local emptyRooms = DetectEmptySpaceRooms(walls, 8)

	-- Append these new rooms
	for i, obb in ipairs(emptyRooms) do
		obb.Name = ("EmptyRoom_%d"):format(i)
		rooms[#rooms+1] = obb
	end

	self.Rooms = rooms
	return rooms
end

-- ---------- Publish lightweight data to clients ----------
-- We send: Name, Center(Vector3), Size(Vector3), IsCorridor(boolean), CFrame(CFrame)
function MinimapServer:Publish()
	local out = {}
	for _, obb in ipairs(self.Rooms) do
		table.insert(out, {
			Name = obb.Name,
			Center = obb.Center,
			Size = obb.Size,
			IsCorridor = obb.IsCorridor,
			CFrame = obb.CFrame,
			calculatedLookVector = obb.calculatedLookVector
		})
	end
	self.Version = self.Version + 1
	minimapUpdate:FireAllClients(out, self.Version)
end

-- RemoteFunction handler (client can request current data)
minimapRequest.OnServerInvoke = function(playerRequester)
	return (function()
		-- return current set and version
		local out = {}
		for _, obb in ipairs(MinimapServerInstance.Rooms) do
			table.insert(out, {
				Name = obb.Name,
				Center = obb.Center,
				Size = obb.Size,
				IsCorridor = obb.IsCorridor,
				CFrame = obb.CFrame
			})
		end
		return out, MinimapServerInstance.Version
	end)()
end

-- ---------- Start scanning loop ----------

function MinimapServer:Start()
	if MinimapServerInstance then return MinimapServerInstance end
	MinimapServerInstance = self

	-- initial scan
	self:ScanAndBuild()
	self:Publish()

	-- scanning loop
	RunService.Heartbeat:Connect(function(dt)
		self._accum = self._accum + dt
		if self._accum >= self.SCAN_INTERVAL then
			self._accum = 0
			self:ScanAndBuild()
			self:Publish()
		end
	end)
	return self
end

return MinimapServer
