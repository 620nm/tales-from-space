local matter_look = require("@helpers/matter_look")

-- Every tile of a connected body reports one regime.
--
-- A flood of water and a released canister of chlorine each spread over many
-- tiles, and different tiles of them are in different states: a flood's rim
-- has only just arrived while its middle is long wet; a gas is stirred hard
-- at the valve and still at the far wall. Whatever regime the body takes, all
-- its tiles take the same, so a body is never drawn half rippling and half
-- still. Bodies are read per rung: the tiles holding one rung of one look.

t.set_breathing(false)

local MIN_BODY = 4

-- The regimes seen on each shell rung of one look across the room.
local function regimes_by_rung(player: number, look: string): { [number]: { [number]: number } }
    local found: { [number]: { [number]: number } } = {}
    for x = 1, 9 do
        for y = 1, 5 do
            for _, part in ipairs(matter_look.parts(player, x, y, look)) do
                if part.blocks ~= nil then
                    local rung = found[part.rung] or {}
                    found[part.rung] = rung
                    rung[part.regime] = (rung[part.regime] or 0) + 1
                end
            end
        end
    end
    return found
end

local function assert_one_regime_per_rung(player: number, look: string, why: string)
    local rungs = regimes_by_rung(player, look)
    local widest = 0
    for rung, regimes in pairs(rungs) do
        local kinds, tiles = 0, 0
        for _, count in pairs(regimes) do
            kinds += 1
            tiles += count
        end
        assert(kinds == 1, string.format("%s: rung %d of %s is in %d regimes at once", why, rung, look, kinds))
        widest = math.max(widest, tiles)
    end
    assert(widest >= MIN_BODY, string.format("%s: the body spans %d tiles, too few to prove the rule", why, widest))
end

-- A flood three seconds on: the middle has been wet and changing, the rim
-- only just reached.
local flood = matter_look.room({ { x = 5, y = 3, rows = matter_look.water(20000) } })
t.run_seconds(3)
assert_one_regime_per_rung(flood, "puddle", "flood")

-- A canister two seconds after the valve opens.
local release = matter_look.room({ { x = 5, y = 3, rows = '("chlorine", 100.0)' } })
t.run_seconds(2)
assert_one_regime_per_rung(release, "cloud", "gas")
