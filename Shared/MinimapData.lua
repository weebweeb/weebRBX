
-- Authoritative room list replicated to clients

local MinimapData = {
	Rooms = {},      -- array of serialized obbs: {Name, Center={x,z}, Size={x,z}, IsCorridor, Rotation}
	Version = 0
}

return MinimapData

