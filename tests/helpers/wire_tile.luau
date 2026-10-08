-- Single-level wire address for spec action targets.
local wire_tile = {}

export type WireAddress = { x: number, y: number, z: number }

-- The engine's wire tile is plane-absolute {x, y, z} with required z;
-- this pack plays on one level, so every address rides z = 0.
function wire_tile.at(x: number, y: number): WireAddress
    return { x = x, y = y, z = 0 }
end

return wire_tile
