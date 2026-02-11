

local function getDescendantsOfType(className : string, itemToSearch: Instance) : {any?}
	local returnProduct : {any?} = {}
	for _, v in pairs(itemToSearch:GetDescendants()) do
		if v:IsA(className) then
			table.insert(returnProduct, v)
		end
	end
	return returnProduct
end

return getDescendantsOfType