-- THE BLAST, written once: what a detonation does to bodies and to the room.
--
-- Three halves, called in detonation order. `apply` is the hurt: every
-- body within a tile and a half that the blast can see, in two
-- Chebyshev bands off the blast tile -- the tile itself and the ring
-- round it -- with no aimed part, so each blow falls toward its
-- victim's own default zone. `cast` is the part the room sees and
-- hears: flash, ring, sparks, shake, glow, two fires and the blast
-- itself, every one of them on the FOV-filtered lanes. `burst` throws
-- the volley whose fragments the tick flies home; their dirt lands
-- later, a landing tile at a time off the settle hook
-- (items/weapons/frag_grenade.luau).
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

-- The volley: what flies is what rests (lib/residue_kinds.luau), laid
-- down where the pellets land off the settle hook.
function blast.burst(at: TileAddress): ()
    sim.volley_discharge(at.x, at.y, VOLLEY_RADIUS, VOLLEY_DAMAGE, residue_kinds.dust_per_blast)
end

-- The part the room sees. Strengths and durations are the choreography:
-- flash peaks first and shortest, the ring and sparks follow, shake and
-- glow decay together. The jolt is the pack's own feel, well under the
-- 32 px ceiling. The two fires are the sheet's nine-frame explosion
-- played once, the second offset half a cell so the blast has width.
function blast.cast(at: TileAddress): ()
    sim.visual.flash({ at = at, strength = 0.7, duration = 0.25 })
    sim.visual.ring({ at = at, strength = 1.5, duration = 0.4 })
    sim.visual.sparks({ at = at, strength = 14, duration = 0.5 })
    sim.visual.shake({ at = at, strength = 8, duration = 0.6 })
    sim.visual.glow({ at = at, strength = 2, duration = 0.6 })
    sim.visual.spawn({ visual_layer = "effects", at = at, sprite = "blast_fire", duration = 1.0 })
    sim.visual.spawn({
        visual_layer = "effects",
        at = at,
        sprite = "blast_fire",
        duration = 0.8,
        offset_x = 8,
        offset_y = -8,
    })
    sim.sound.play({ asset = "lunatic/tfs:sound/explosion", at = at })
end

return blast
