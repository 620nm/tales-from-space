-- The morgue's dead at map start, the tg way: `dead_body_placer`
-- (tgstation/code/modules/mapping/mapping_helpers.dm:975-1026) puts three
-- bodies (:982) into closed morgue trays (:995-1000), a tray each unless
-- there are fewer trays than bodies (:1010-1013), picked at random.
-- Each is a human seated straight into its chamber (`sim.body.spawn` `into`);
-- its `entity.spawn.done` dresses it in a crew job's kit, names it, deals it
-- the morgue class's death (:984), then lays it dead and settled, as tg's
-- `new()` then `death()` (code/modules/lost_crew/lost_crew_manager.dm:25-26).
-- Its look is the spawn's own roll (tg `randomize_human_normie`). The
-- chamber's watch then lights the lamp for the dead
-- (`lib/closets/chamber_watch.luau`).
--
-- Divergences: tg searches the placer's own area (:993-996); a map here
-- places no helper, so every closed chamber on it is a candidate. tg's
-- morgue class assigns no job, so its cadavers go bare
-- (code/modules/lost_crew/scenarios.dm:49-53); these wear the kit of one of
-- the station class's assignments (scenarios.dm:6-13), so an attendant can
-- tell whose they were.
-- NOT PORTED: the body bag and its name tag (mapping_helpers.dm:1014-1022);
-- ghost roles and the revival reward (lost_crew_manager.dm:44-80); every cause
-- of death but the toolbox, and the post-mortem limb, organ and decay rolls
-- (scenarios.dm:19-40), which need weapons and wounds this pack lacks; the
-- dragged blood loss and the date of death
-- (code/modules/lost_crew/damages/_damages.dm:91-92).

local chamber_watch = require("@lib/closets/chamber_watch")
local closet_data = require("@lib/closets/data")
local crew_names = require("@lib/crew/names")
local crew_outfits = require("@lib/crew/outfits")

local cadaver_stock = {}

local CHAMBER = "cadaver_chamber"
local PLAN = "human"
local STREAM = "cadaver_stock"
-- `bodycount = 3` (mapping_helpers.dm:982).
local BODY_COUNT = 3
-- The station class's assignments this pack has a job for: engineer,
-- medical, security and civilian; science and cargo have none here
-- (scenarios.dm:6-13).
local KITS: { { crew_outfits.OutfitRow } } =
    { crew_outfits.engineer, crew_outfits.medic, crew_outfits.security, crew_outfits.assistant }
-- The toolbox death (code/modules/lost_crew/damages/melee.dm:6-16): 5 to 15
-- hits by severity, each on a limb picked at random (`get_all_limbs`). A
-- toolbox blow here is 10 brute (items/gear/toolbox.luau's swing).
local MIN_HITS = 5
local MAX_HITS = 15
local TOOLBOX_BRUTE = 10
local LIMBS = { "chest", "head", "l_arm", "r_arm", "l_leg", "r_leg" }

local function roll(count: number): number
    return math.min(count, math.floor(sim.random(STREAM) * count) + 1)
end

local function closed_chambers(): { Handle }
    local closed: { Handle } = {}
    for _, chamber in ipairs(sim.query.all(CHAMBER)) do
        if chamber.state == closet_data.closed_state then
            table.insert(closed, chamber)
        end
    end
    return closed
end

-- Spawns the map's dead into its closed chambers. A map without one stocks
-- nobody, as tg logs and returns (mapping_helpers.dm:1003-1008).
function cadaver_stock.stock(): ()
    local chambers = closed_chambers()
    if #chambers == 0 then
        return
    end
    local reuse = #chambers < BODY_COUNT
    for _ = 1, BODY_COUNT do
        local index = roll(#chambers)
        local chamber = chambers[index]
        if not reuse then
            table.remove(chambers, index)
        end
        sim.body.spawn({ plan = PLAN, into = chamber })
    end
end

local function dress(body: Handle): ()
    for _, row in ipairs(KITS[roll(#KITS)]) do
        sim.body.dress({ body = body, slot = row.slot, item = row.item, contents = row.contents })
    end
end

local function strike(body: Handle): ()
    local hits = math.floor((MAX_HITS - MIN_HITS) * sim.random(STREAM) + MIN_HITS)
    for _ = 1, hits do
        local limb = LIMBS[roll(#LIMBS)]
        sim.damage.apply({ target = body, amounts = { brute = TOOLBOX_BRUTE }, part = limb })
    end
end

local function name_of(): string
    local given = crew_names.given[roll(#crew_names.given)]
    return given .. " " .. crew_names.family[roll(#crew_names.family)]
end

-- A body seated into a cadaver chamber is one of the stock: nothing else
-- spawns into one, so the answer keeps no book of its own.
local function on_spawned(ev: EntitySpawnDonePayload): ()
    local chamber = ev.into
    if chamber == nil or chamber.prototype ~= CHAMBER then
        return
    end
    local body = ev.entity
    if ev.outcome ~= "completed" or body == nil then
        return
    end
    dress(body)
    local name = name_of()
    strike(body)
    -- tg's `death()`: the blows alone need not kill, so the heart is stopped,
    -- the latch that keeps a corpse dead (`bodies/human.luau`).
    sim.fail_component(body, { tag = "heart" })
    sim.set_body_facts(body, { animate = false, settled = true, controllable = false, name = name })
    chamber_watch.start(chamber)
end

-- Binds the spawn answers on the plan's own behavior (`bodies/human.luau`):
-- an `entity.spawn.done` answers the spawned definition, not its issuer.
function cadaver_stock.install(behavior: Definition): ()
    behavior:handle("entity.spawn.done", { kind = "react" }, on_spawned)
end

return cadaver_stock
