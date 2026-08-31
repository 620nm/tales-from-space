-- "Gas meters leak air from pipes."
--
-- They do not, and this file is the standing answer. There is no
-- mechanism for it to be true: a meter declares no `atmos` block, so it
-- never becomes a pipe device and never takes a tile out of a network;
-- it holds no gas of its own; its reading is a READ of the net it
-- stands over; and bolting one down tests a bitmask rather than cutting
-- anything. tg agrees -- `meter.dm` is not an atmospherics machine at
-- all.
--
-- None of that is falsifiable by looking at it, so it is written here
-- as arithmetic instead, with the two confounders the report most
-- plausibly came from actually built:
--
--   * a run fed by an ANCHORED CANISTER on a connector port, which is
--     where a main's moles genuinely do move about while you watch;
--   * a gauge put down by the RPD (`ctx.fit`) rather than mapped, which
--     is a different placement path and the one a player uses.
--
-- The shape of the proof is a matched pair. Two identical mains on one
-- station, fed by two identical bottles, one of them gauged and one of
-- them not: they run the same ticks in the same sim, so anything the
-- gauge does to its main shows up as the two disagreeing. No epsilon on
-- the tick count, no second world to keep in step.

-- NOBODY IN HERE IS BREATHING. A crewman with lungs is a chemical
-- plant standing in the room: his lungs are a driven vessel that holds
-- several litres of the air inside itself and turns what it takes in
-- into something else (docs/BIOLOGY.md, `sim/holder/bellows.rs`). That
-- is a source and a sink, and the books below are the ATMOSPHERICS
-- engine's -- so the crew are switched off as scaffolding, the same
-- standing `t.set_health` has.
t.set_breathing(false)

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

local function lying_at(x, y, id)
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

local function moles(x, y)
    local total = 0.0
    for _, n in pairs(t.pipe_gas(x, y) or {}) do
        total += n
    end
    return total
end

-- ---------------------------------------------------------------
-- Two mains, two bottles, one gauge.
-- ---------------------------------------------------------------
t.world([==[(
    name: "matched mains",
    legend: {
        '.': (turf: Plating),
        'o': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#..oo..#",
        "#......#",
        "########",
    ],
    spawns: [(4, 2)],
    items: [(3, 2, "wrench"), (3, 1, "pipe_meter")],
    pipes: [
        (2, 1, 4), (3, 1, 4), (4, 1, 4), (5, 1, 4),
        (2, 3, 4), (3, 3, 4), (4, 3, 4), (5, 3, 4),
    ],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (1, 1, "connector_port"),
        (1, 1, "canister", { "air": "canister_air", "open": true }),
        (1, 3, "connector_port"),
        (1, 3, "canister", { "air": "canister_air", "open": true }),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- The two mains start life the same, which is the premise everything
-- below rests on.
t.run_seconds(4)
assert(math.abs(moles(3, 1) - moles(3, 3)) < 1e-9, "the twins start matched")

-- Bolt a gauge onto the northern main, the way a player does: wrench in
-- hand, fitting on the tile, two seconds of work.
t.click(p, 3, 2, t.target_at(3, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")
walk(p, "north")
t.click(p, 3, 1, t.target_at(3, 1, "pipe_meter"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1).id == "meter", "a gauge stands on the northern main")
assert(not lying_at(3, 1, "pipe_meter"), "the fitting was spent into it")

-- The moment it goes down, and again after a long shift of being read.
assert(
    math.abs(moles(3, 1) - moles(3, 3)) < 1e-9,
    "bolting it down took nothing out: " .. moles(3, 1) .. " vs " .. moles(3, 3)
)

t.run_seconds(60)
local gauged, plain = moles(3, 1), moles(3, 3)
assert(
    math.abs(gauged - plain) < 1e-9,
    "sixty seconds of being read cost the main nothing: " .. gauged .. " vs " .. plain
)
assert(gauged > 0.0, "and both mains are actually carrying something")
assert(
    math.abs(t.pipe_pressure(3, 1) - t.pipe_pressure(3, 3)) < 1e-9,
    "which is the same statement on a gauge"
)

-- Nor did it push anything up onto the deck. The two decks match for
-- the same reason the two mains do: whatever ordinary air the room
-- holds, the gauged tile holds exactly as much of it.
assert(
    math.abs(t.room_pressure(3, 1) - t.room_pressure(3, 3)) < 1e-9,
    "the deck over the gauge is the deck over the bare main: "
        .. t.room_pressure(3, 1) .. " vs " .. t.room_pressure(3, 3)
)

-- And the bottles paid the same price, which is where a leak into the
-- room would have to have come from.
assert(
    math.abs(t.canister_pressure(1, 1) - t.canister_pressure(1, 3)) < 1e-9,
    "the two bottles are equally spent"
)

-- ---------------------------------------------------------------
-- The other placement path: an RPD-generated gauge onto a SEALED main.
--
-- No bottle here, so the run is a closed body of gas and conservation
-- is an absolute rather than a comparison. `ctx.fit` is a different
-- door into construction from the wrench above, and it is the one a
-- player actually uses.
-- ---------------------------------------------------------------
t.world([==[(
    name: "sealed main",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "######",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "rpd")],
    pipes: [(1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4)],
)]==], 7)

local r = t.join()
t.tick()
t.run_seconds(2)

local sealed = moles(2, 1)
assert(sealed > 0.0, "a mapped main is commissioned live: " .. sealed)

t.click(r, 2, 2, t.target_at(2, 2, "rpd"))
t.run_ticks(2)
t.use_self(r)
t.tick()

local function pick(field, label)
    for _, toggle in ipairs(t.ui(r).toggles) do
        if toggle.field == field and toggle.option ~= nil and toggle.label == label then
            return toggle.option
        end
    end
    error("no " .. field .. " button labelled " .. label)
end

local function set(field, label)
    t.ui_act(r, "toggle", '{"field":"' .. field .. '","option":"' .. pick(field, label) .. '"}')
    t.tick()
end

set("dial1", "Meter")
set("dial2", "3")
t.click(r, 2, 1)
t.run_seconds(1.0)
assert(t.structure_at(2, 1).id == "meter", "the RPD put a gauge on the main")

assert(
    math.abs(moles(2, 1) - sealed) < 1e-9,
    "and the sealed main is exactly as full as it was: " .. moles(2, 1) .. " vs " .. sealed
)

t.run_seconds(60)
assert(
    math.abs(moles(2, 1) - sealed) < 1e-9,
    "still, a minute later: " .. moles(2, 1) .. " vs " .. sealed
)
assert(t.pipe(2, 1) == 4, "the run it stands on was never cut")
assert(t.structure_at(2, 1).id == "meter", "and it is still standing on it")
