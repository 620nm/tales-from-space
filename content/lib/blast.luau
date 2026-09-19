-- THE BLAST, written once: what a detonation does to bodies and to the room.
--
-- Four quarters, called in detonation order. `apply` is the hurt: every
-- body within a tile and a half that the blast can see, in two
-- Chebyshev bands off the blast tile -- the tile itself and the ring
-- round it -- with no aimed part, so each blow falls toward its
-- victim's own default zone. `ground` is the fallout: one blast's
-- worth of cloudy dirt over the same nine tiles, center-weighted, at
-- detonate time. `cast` is the part the room sees and hears: flash,
-- ring, sparks, shake, glow, one fire on the blast tile and the blast
-- itself, every one of them on the FOV-filtered lanes. `burst` throws
-- the volley whose fragments the tick flies home; their own dirt --
-- shards -- lands later, a landing tile at a time off the settle
-- signals (items/weapons/frag_grenade.luau).
--
-- The bands are the pack's own numbers, not tg's: tg's frag grenade
-- speaks in explosion radii (ex_heavy 1, ex_light 3, ex_flame 4,
-- syndieminibomb.dm:35-37) and this engine has no such system. 40 is
-- the most any handler may ask for (the engine's MAX_SCRIPT_HIT), and
-- the ring's 15/10 is a wound, not a kill. The volley is the engine's
-- reference discharge (count 15, range 10, force 14, bounces 2): tg's
-- shrapnel force and ricochets (shrapnel.dm:32,36) thrown to the
-- adjudicated ten tiles at less than a fifth of tg's ring count -- a
-- radius-10 ring is 80 turfs (pellet_cloud.dm:171-174) -- keeping the
-- ledger readable while the direct blast carries the kill.
local residue_kinds = require("@lib/residue_kinds")

local RADIUS = 1.5
local CENTER: { [string]: number } = { brute = 40, burn = 20 }
local RING: { [string]: number } = { brute = 15, burn = 10 }
local VOLLEY_RADIUS = 10
local VOLLEY_DAMAGE = 14

local blast = {}

-- Every body the blast can see. The query is Euclidean, so 1.5 reaches
-- exactly the eight tiles round the blast (a diagonal is root two);
-- the bands are Chebyshev, so the tile itself is the center and
-- everything else the ring. `sim.body` is the filter: items, machines
-- and ghosts on those tiles are not bodies and take nothing.
function blast.apply(at: TileAddress): ()
    for _, target in ipairs(sim.query.range(at, RADIUS, {})) do
        if sim.body(target) ~= nil then
            local tile = target.tile
            if sim.query.los(at, tile) then
                local distance = math.max(math.abs(tile.x - at.x), math.abs(tile.y - at.y))
                sim.damage.apply({
                    target = target,
                    amounts = if distance == 0 then CENTER else RING,
                })
            end
        end
    end
end

-- The volley: fifteen pellets the tick flies home, their shards laid
-- down where they land off the settle signals. The blast area wears
-- its own cloudy dirt instead (ground below), never shards.
function blast.burst(at: TileAddress): ()
    sim.volley_discharge(at.x, at.y, VOLLEY_RADIUS, VOLLEY_DAMAGE, residue_kinds.pellets_per_volley)
end

-- The fallout, grounded where the blast went off: one blast's worth
-- of cloudy dirt over the nine tiles, the ring dusted a fragment each
-- and the rest heaped on the center (7 with the reference 15). The
-- center is the tile the ash already sits on, so fallout and ash
-- agree about where the blast was. Wall tiles in the nine refuse with
-- the engine's force sentence -- dirt rests where a thing can lie --
-- and the rest still land.
local RING_SHARE = 1
function blast.ground(at: TileAddress): ()
    local center_share = residue_kinds.cloudy_per_blast - 8 * RING_SHARE
    for dy = -1, 1 do
        for dx = -1, 1 do
            local share = if dx == 0 and dy == 0 then center_share else RING_SHARE
            sim.volley_fallout_deposit(at.x + dx, at.y + dy, share)
        end
    end
end

-- The part the room sees. Strengths and durations are the choreography:
-- flash peaks first and shortest, the ring and sparks follow, shake and
-- glow decay together. The jolt is the pack's own feel, well under the
-- 32 px ceiling. The fire is the sheet's nine-frame explosion played
-- once, on the blast tile and nowhere else: one blast, one cloud.
function blast.cast(at: TileAddress): ()
    sim.visual.flash({ at = at, strength = 0.7, duration = 0.25 })
    sim.visual.ring({ at = at, strength = 1.5, duration = 0.4 })
    sim.visual.sparks({ at = at, strength = 14, duration = 0.5 })
    sim.visual.shake({ at = at, strength = 8, duration = 0.6 })
    sim.visual.glow({ at = at, strength = 2, duration = 0.6 })
    sim.visual.spawn({ visual_layer = "effects", at = at, sprite = "blast_fire", duration = 1.0 })
    sim.sound.play({ asset = "lunatic/tfs:sound/explosion", at = at })
end

return blast
