-- Hosts minimap server handler
local MinimapServer = require(script.Parent:WaitForChild("MinimapService"))

local mapRoot = workspace:FindFirstChild("Map") or workspace
local server = MinimapServer.new(mapRoot)
server:Start()

-- expose instance
_G.MinimapServerInstance = server

local function weld(a, b)
	if not a or not b then return end
	a.Anchored = false
	b.Anchored = false
	a.CFrame = ((b.CFrame - b.CFrame.UpVector * 1.7) - b.CFrame.rightVector * 0.3) * CFrame.Angles(math.rad(-160), math.rad(-180), math.rad(30))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = a
	return weld
end

game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TabletVisible").OnServerEvent:Connect(function(player, visible)
	local tablet = player.Character:FindFirstChild("Tablet")
	if tablet then
		tablet:Destroy()
	end
	if visible then
		local tablet = game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Misc"):WaitForChild("Tablet"):Clone()
		tablet.Parent = player.Character
		weld(tablet, player.Character:WaitForChild("Right Arm", 1))
	else
		local tablet = player.Character:FindFirstChild("Tablet")
		if tablet then
			tablet:Destroy()
		end
	end
end)


