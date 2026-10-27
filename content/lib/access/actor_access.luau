-- The station access a body carries (tg GetID): what its hands hold, the
-- item worn in its `id` slot, and a card in the `card` slot of any of those
-- items. A card inside a backpack or other storage counts for nothing.
-- Return-only: `access.derive` writes the body's derived layer, nothing else.
local actor_access = {}

local STATION_REALM = "station"
local ID_SLOT = "id"
local CARD_SLOT = "card"

function actor_access.derive(ev: AccessDerivePayload)
    local union = sim.access.empty(STATION_REALM)
    for _, row in ipairs(sim.inventory(ev.holder)) do
        local place = row.location
        local carried = place.kind == "hand"
            or (place.kind == "worn" and place.equipment_slot == ID_SLOT)
        if carried then
            union = union:union(sim.access.held(row.item, STATION_REALM))
            local card = row.item:item_slot(CARD_SLOT)
            if card ~= nil then
                union = union:union(sim.access.held(card, STATION_REALM))
            end
        end
    end
    return { sets = { union:data() } }
end

return actor_access
