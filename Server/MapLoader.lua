--[[
Map loader system
Should be self explanatory- see game.ReplicatedStorage.Maps.ExampleMap for example usage

Some notes:
Maps should be folder instances, with each collective being its own model, but please do not stack models
Players will always spawn at the part labeled 'Spawn' inside the map model, it should be a direct descendant of the map folder
]]
-- @a_lyve


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapsFolder = ReplicatedStorage:WaitForChild("Maps")

local MapLoader = {}
MapLoader.__index = MapLoader

local LoadedMaps = {}

function MapLoader.new()
	return setmetatable({}, MapLoader)
end



local function cloneChunked(sourceParent, targetParent, chunkSize)
	local children = sourceParent:GetChildren()
	local index = 1
	local RandomPosition = Vector3.new(math.random(-1000000,1000000), 500, math.random(-1000000,1000000))
	if LoadedMaps[RandomPosition] then --TODO: Implemement some additional checking to make sure maps dont collide
		repeat 
			task.wait(1);
			RandomPosition = Vector3.new(math.random(-1000000,1000000), 500, math.random(-1000000,1000000))
		until not LoadedMaps[RandomPosition]
	end
	
	LoadedMaps[RandomPosition] = {}

	while index <= #children do
		for i = index, math.min(index + chunkSize - 1, #children) do
			local clonedItem = children[i]:Clone()
			if clonedItem:IsA("BasePart") then
				clonedItem.Parent = targetParent
				clonedItem.CFrame = clonedItem.CFrame + Vector3.new(RandomPosition, RandomPosition, RandomPosition)
				table.insert(LoadedMaps[RandomPosition], clonedItem)
			else
				clonedItem.Parent = targetParent
			end
			
		end
		index += chunkSize
		task.wait()
	end
end


function MapLoader:LoadRandom()
	local maps = MapsFolder:GetChildren()
	if #maps == 0 then
		error("No maps found in ReplicatedStorage.Maps")
	end
	local chosenMap = maps[math.random(1, #maps)]
	if not chosenMap then
		error("Error finding map")
	end
	
	local folder = Instance.new("Folder")
	folder.Name = "ActiveMap"
	folder.Parent = workspace

	cloneChunked(chosenMap, folder, 25)

	return folder
end


function MapLoader:LoadSpecific(object)
	if not object then
		error("No map provided")
	end
	local folder = Instance.new("Folder")
	folder.Name = "LoadedAltMap"
	folder.Parent = workspace
	
	cloneChunked(object, folder, 25)
	
	return folder
end

function MapLoader:Load(name)
	local mapTemplate = MapsFolder:FindFirstChild(name)
	if not mapTemplate then
		error("Map not found: " .. name)
	end

	local folder = Instance.new("Folder")
	folder.Name = "ActiveMap"
	folder.Parent = workspace

	cloneChunked(mapTemplate, folder, 25)

	return folder
end

return MapLoader
