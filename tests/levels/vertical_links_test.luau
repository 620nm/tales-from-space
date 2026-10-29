-- A network never crosses levels except through a dedicated fixture: the
-- multi-level cable hub and the multi-deck pipe adapter, each joining only
-- its own kind stacked directly above or below it on the same channel
-- (`content/compositions.luau`; tg power/multiz.dm:1-12 and
-- pipes/multiz.dm:2-60). Three things a player can see:
--
--   1. a hub pair carries a generator's power from the basement to a lamp
--      upstairs, cutting one hub leaves the upstairs backbone dead (the
--      panel's cell keeps the lamp lit a while), and laying it again from a
--      coil set to "hub" brings it back;
--   2. an adapter pair shares gas between two levels;
--   3. plain cable stacked over plain cable joins nothing.
--
-- The lamp is on the ground and the generator below it because bare
-- `(x, y)` reads such as `t.lit` and `t.network_segment` name level 0 (the
-- engine's `docs/luau-api/world-testing.md`).
local BASEMENT = -1
local GROUND = 0

-- Whether the upstairs backbone carries the generator's power.
local function backbone_live(): boolean
    return t.network_segment(2, 2, "power", "l2").carrying
end

local LEGEND = [==[
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'h': (composition: (components: [(component: "station_base")])),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'l': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Light), light: Some("#FFFFFF")),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
]==]

local function run_piece(network: string, x: number, y: number, channel: string, kind: string): string
    return "(x: "
        .. x
        .. ", y: "
        .. y
        .. ', network: "'
        .. network
        .. '", channel: "'
        .. channel
        .. '", kind: "'
        .. kind
        .. '", facing: 15),'
end

-- The room circuit (l1) and the backbone (l2) cover the upstairs; the
-- generator below feeds the backbone. The piece at (3, 2) on the backbone,
-- on both levels, is `joint`: a hub, or plain cable for the control.
local function power_world(joint: string)
    local upstairs = ""
    for _, tile in ipairs({ { 1, 1 }, { 2, 1 }, { 3, 1 }, { 1, 2 }, { 2, 2 }, { 3, 2 } }) do
        local at_joint = tile[1] == 3 and tile[2] == 2
        if not at_joint then
            upstairs ..= run_piece("power", tile[1], tile[2], "l1", "cable")
        end
        upstairs ..= run_piece("power", tile[1], tile[2], "l2", if at_joint then joint else "cable")
    end
    local basement = run_piece("power", 2, 2, "l2", "cable") .. run_piece("power", 3, 2, "l2", joint)
    t.world(
        '(name: "stacked power", tags: ["terrestrial"], levels_below_ground: 1,'
            .. " environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),"
            .. " legend: {\n"
            .. LEGEND
            .. "\n    }, levels: ["
            .. '(rows: ["#####", "#...#", "#.gh#", "#####"], structures: [], networks: ['
            .. basement
            .. "]),"
            .. '(rows: ["#####", "#alo#", "#..h#", "#####"],'
            .. ' structures: [(2, 2, "player_spawn"), (1, 1, "apc")],'
            .. ' items: [(2, 2, "wirecutters"), (2, 2, "cable_coil")], networks: ['
            .. upstairs
            .. "])])",
        7
    )
end

-- 1. The hub pair.
power_world("hub")
local p = t.join()
t.run_seconds(3)
assert(backbone_live(), "the hubs join the backbone to the generator below")
assert(t.lit(2, 1), "and the lamp upstairs burns")

t.click(p, 2, 2, t.target_at(p, 2, 2, "wirecutters"))
t.run_ticks(2)
t.click_network(p, 3, 2, assert(t.network_instance(3, 2, "power", "l2", GROUND)))
t.run_seconds(1.5)
assert(t.network_instance(3, 2, "power", "l2", GROUND) == nil, "the upstairs hub came up")
assert(t.network_instance(3, 2, "power", "l2", BASEMENT) ~= nil, "and the one below it did not")
t.run_seconds(3)
assert(not backbone_live(), "with one hub gone the backbone loses the generator")

-- Laying one again: the coil's dial runs yellow, blue, red, then the hubs
-- (yellow first); three presses from a fresh coil reach the yellow hub.
t.drop(p)
t.run_ticks(2)
t.click(p, 2, 2, t.target_at(p, 2, 2, "cable_coil"))
t.run_ticks(2)
for _ = 1, 3 do
    t.use_self(p)
    t.run_ticks(2)
end
t.click(p, 3, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(t.network_instance(3, 2, "power", "l2", GROUND) ~= nil, "the coil laid a hub")
t.run_seconds(3)
assert(backbone_live(), "and the pair carries the power again")

-- 3. The control: plain cable stacked over plain cable is two circuits.
power_world("cable")
t.join()
assert(not backbone_live(), "plain cable over plain cable joins nothing")

-- 2. The adapter pair.
t.set_breathing(false)
t.world(
    [==[(
    name: "stacked pipes",
    tags: ["terrestrial"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: ["#######", "#.....#", "#######"],
            structures: [],
            networks: [
                (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 5, y: 1, network: "pipe", channel: "l3", kind: "adapter", facing: 15),
            ],
        ),
        (
            rows: ["#######", "#.....#", "#######"],
            structures: [(1, 1, "player_spawn"), (2, 1, "stationary_tank", "anchored", ("o2", 9000.0))],
            networks: [
                (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 5, y: 1, network: "pipe", channel: "l3", kind: "adapter", facing: 15),
            ],
        ),
    ],
)]==],
    7
)
t.join()
t.run_seconds(5)

local function pressure(x: number, level: number): number
    local id = assert(t.network_instance(x, 1, "pipe", "l3", level))
    return assert(t.network_pressure(x, 1, id, level))
end
local upstairs_kpa = pressure(3, GROUND)
local downstairs_kpa = pressure(3, BASEMENT)
assert(upstairs_kpa > 1000, "the tank charges its own run, got " .. upstairs_kpa)
assert(
    math.abs(upstairs_kpa - downstairs_kpa) < upstairs_kpa * 0.05,
    "the adapter pair shares the gas with the level below: "
        .. upstairs_kpa
        .. " vs "
        .. downstairs_kpa
)
