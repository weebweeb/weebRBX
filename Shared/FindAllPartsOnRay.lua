

local function findAllPartsOnRay(origin: Vector3, direction: Vector3, raycastParams: RaycastParams?): {BasePart}
	local targets = {}
	local maxDistance = 10
	local maxParts = 10
	local currentDistance = 0

	local params = raycastParams or RaycastParams.new()

	repeat
		local remainingDistance = maxDistance - currentDistance
		if remainingDistance <= 0 then break end

		local currentOrigin = origin + direction.Unit * currentDistance
		local result = workspace:Raycast(currentOrigin, direction.Unit * remainingDistance, params)

		if result then
			local target = result.Instance
			table.insert(targets, target)

			currentDistance = currentDistance + (result.Position - currentOrigin).Magnitude + 0.01

			if params.FilterDescendantsInstances then
				table.insert(params.FilterDescendantsInstances, target)
			else
				params.FilterDescendantsInstances = {target}
				params.FilterType = Enum.RaycastFilterType.Exclude
			end
		else
			break
		end

	until #targets >= maxParts

	return targets
end

return findAllPartsOnRay