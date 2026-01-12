-- Scrap/Object definitions are registered here

-- For context: ToolTemplate is what will be used to display the tool when the player is holding the item, 
-- ModelTemplate is what will be shown when the item is dropped
-- Meta is a table that can be used to store extra information about the item, for example the value of a scrap item (Meta.Value) or whether 
-- an item is to be purchased in a shop (Meta.ShopLevel) (in this case, its Meta.Value will be price the item will be purchased at)
-- Meta.ShopStats is what players will purchase the item for in the shop, and other stats like its luck value
-- Meta.ShopStats.Luck is the chance of an item appearing in the shop each round, should increase by half its own value each round
-- A luck value of 1 always appears in the shop, and a luck value of 0 never appears in the shop
-- Carryable indicates whether the item can be placed in the player's backpack or must be dragged
-- Kg is the weight of the item, <= 2 is light <= 10 is medium <=40 is heavy and at >40 items will be dragged

local ObjectService = require(game.ReplicatedStorage.Shared.ObjectService)
local Scrap = game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Items"):WaitForChild("Scrap")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ObjectService.Server.registerDefinition("ExampleScrap", {
	Name = "ExampleScrap",
	Kg = 1.5,
	Carryable = true,
	ToolTemplate = Scrap:WaitForChild("ExampleScrap"),
	ModelTemplate = Scrap:WaitForChild("ExampleScrapModel"),
	Meta = {Value = 5},
})

ObjectService.Server.registerDefinition("ExampleMediumScrap", {
	Name = "ExampleScrap",
	Kg = 5,
	Carryable = true,
	ToolTemplate = Scrap:WaitForChild("ExampleBigScrap"),
	ModelTemplate = Scrap:WaitForChild("ExampleBigScrapModel"),
	Meta = {Value = 5},
})

ObjectService.Server.registerDefinition("ExampleHeavyCarryableScrap", {
	Name = "ExampleScrap",
	Kg = 10,
	Carryable = true,
	ToolTemplate = Scrap:WaitForChild("ExampleBigScrap"),
	ModelTemplate = Scrap:WaitForChild("ExampleBigScrapModel"),
	Meta = {Value = 5},
})


ObjectService.Server.registerDefinition("HeavyScrap", {
	Name = "HeavyScrap",
	Kg = 45, -- -> TooHeavy (draggable)
	Carryable = false,
	ModelTemplate = Scrap:WaitForChild("HeavyScrap"),
	MaxDragHelpers = 4,
	BaseDragSpeed = 4,
	ExtraHelperBoost = 1.75,
	Meta = {Value = 100}
})


ObjectService.Server.registerDefinition("Flashlight", {
	Name = "Flashlight",
	Kg = 1.5,
	Carryable = true,
	ToolTemplate = Scrap:WaitForChild("ExampleFlashlightTest"),
	ModelTemplate = Scrap:WaitForChild("ExampleScrapModel"),
	Meta = {
		Value = 50, 
		ShopLevel = 1, 
		StoreItem = true, --whether this item should be treated as a dummy store item when first appearing in its model state (use ObjectService:GivePlayerItem to override)
		ShopStats = {
			Section = "Utility",
			Price = 100,
			Luck = 1,   -- chance of appearing in the shop each round, should increase by half its own value each round, with 1 being always appearing and 0 being never appearing
			Charges = 100, -- Charges this item begins with
			ChargeDepletionMethod = "Continuous", -- charge depletion method, one of "Continuous" (flashlights, radar, etc) or "Discrete" (single use items with quantities like flares)
			ChargeDepletionRate = 1 -- Amount of charges depleted every second/use
		} },
	Assistable = true
})


ObjectService.Server.registerDefinition("Bloxy Cola", {
	Name = "Bloxy Cola",
	Kg = 1.5,
	Carryable = true,
	ToolTemplate = Scrap:WaitForChild("ExampleScrap"),
	ModelTemplate = Scrap:WaitForChild("ExampleScrapModel"),
	Meta = {
		Value = 50, 
		ShopLevel = 1, 
		StoreItem = true, 
		ShopStats = {
			Section = "Aid",
			Price = 100,
			Luck = 1/2,   -- chance of appearing in the shop each round, should increase by half its own value each round
			Charges = 2,
			ChargeDepletionMethod = "Discrete", -- charge depletion method, one of "Continuous" (flashlights, radar, etc) or "Discrete" (single use items with quantities like flares)
			ChargeDepletionRate = 1,
		} },
	Assistable = true
})

ObjectService.Server.registerDefinition("Speed Coil", {
	Name = "Speed Coil",
	Kg = 1.5,
	Carryable = true,
	ToolTemplate = Scrap:WaitForChild("ExampleScrap"),
	ModelTemplate = Scrap:WaitForChild("ExampleScrapModel"),
	Meta = {
		Value = 50, 
		ShopLevel = 1, 
		StoreItem = true, 
		ShopStats = {
			Section = "Utility",
			Price = 100,
			Luck = 1/2,   -- chance of appearing in the shop each round, should increase by half its own value each round
		} },
	Assistable = true
})




