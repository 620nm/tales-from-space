-- A connector port needs nothing under it, and that is safe because
-- nothing about it is remembered.
--
-- Josh's ruling (2026-08-16). The first cut made a port refuse to bolt
-- down unless its stub already reached a run: a socket wired to nothing
-- looked like a mistake worth stopping at the wrench. It is not. It got
-- the ORDER of the job wrong -- you put the socket where the bottle has
-- to stand and run pipe out to it afterwards -- and it bought nothing,
-- because the binding between a port and a run is not stored anywhere.
-- `refresh_pipe_topology` re-derives every one of them from the live
-- grid, twice a tick, so a port that was joined to nothing at noon is
-- joined the instant somebody lays a length beside it.
--
-- What that leaves is a mistake you can SEE instead of one you argue
-- with a wrench about: a canister on an unplumbed port fills the room
-- it is standing in (tg's `location.return_air()` fallback,
-- sim/vents.rs), which is a gauge reading, not a silence.
--
-- fittings_test.luau owns the carry-it-across-the-station round trip
-- and rpd_test.luau owns the dispenser's rulebook; this spec is the
-- consequence the two of them share -- what an UNPLUMBED socket does,
-- and what happens to it when the plumbing finally arrives.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- 0.4 s of tg's `atmos_build_speed` (RPD.dm:53), plus slack for the
-- tick the effect lands on.
local function work(p)
    t.run_ticks(12)
end

-- Which button on a dial's row wears that word. Looked up rather than
-- counted, because the fitting roster grows every time a content file
-- lands.
local function pick(p, field, label)
    for _, tog in ipairs(t.ui(p).toggles) do
        if tog.field == field and tog.option ~= nil and tog.label == label then
            return tog.option
        end
    end
    error("no " .. field .. " button labelled " .. label)
end

local function set(p, field, index)
    t.ui_act(p, "toggle", '{"field":"' .. field .. '","option":"' .. index .. '"}')
    t.tick()
end

local RECIPE = "dial1"

-- ---------------------------------------------------------------
-- One sealed room of bare plating with a bottle standing loose in the
-- middle of it and NOT ONE LENGTH OF PIPE ANYWHERE. Every socket below
-- is bolted to deck that has nothing under it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "dry socket",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating, fixture: Some(Canister)),
    },
    rows: [
        "#####",
        "#...#",
        "#.c.#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 2)],
    items: [
        (1, 2, "wrench"),
        (1, 2, "connector_port_fitting"),
        (1, 2, "rpd"),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- The bottle opened the shift loose, because there was no socket under
-- it to open it fastened (`roundstart_state`).
local bottle = t.structure_at(2, 2)
assert(bottle ~= nil and bottle.id == "canister", "the bottle is where the map put it")
assert(bottle.state == "displaced", "standing loose, with nothing under it to fasten to")

-- ---- the wrench path ----
--
-- A fitting, a wrench and two seconds, on deck with no run within
-- reach of the whole map.
t.click(p, 1, 2, t.target_at(1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")

local _ = t.messages(p)
t.click(p, 1, 2, t.target_at(1, 2, "connector_port_fitting"))
t.run_seconds(2.5)
assert(
    not said(p, "There is no pipe under the floor here."),
    "the refusal that used to stop this is gone"
)
local dry = t.structure_at(1, 2)
assert(dry ~= nil and dry.id == "connector_port", "a port stands on bare plating")
assert(dry.state == "anchored", "bolted down, the only state a port has")
assert(
    dry.sprite == "connector_port_n",
    "aimed north -- the deterministic fallback with nothing to aim at: " .. tostring(dry.sprite)
)
assert(t.ledger_has("StructureStep", "connector_port", "built"), "and the raise is on the record")

-- ---- the dispenser path, which is the same path ----
--
-- tg hands the RPD itself to the fitting's `wrench_act` (RPD.dm:572),
-- and lunatic funnels `ctx.fit` through the one `refusal` a pair of
-- hands goes through. So the two either both allow this or both refuse
-- it; there is no second rulebook to keep in step.
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(1, 2, "rpd"))
t.run_ticks(2)
assert(t.hands(p).held == "rpd", "the RPD is in hand")
t.use_self(p)
t.tick()
set(p, RECIPE, pick(p, RECIPE, "Connector"))

local _ = t.messages(p)
-- Under the bottle: a fitting goes UNDER the deck, so what is standing
-- on the tile is not in its way (tg's `wrench_act` looks for
-- conflicting atmospherics on the turf and at nothing else).
t.click(p, 2, 2)
work(p)
assert(
    not said(p, "There is no pipe under the floor here."),
    "and it is gone from the dispenser path too"
)
-- Asked by name, because `structure_at` resolves fittings LAST and the
-- bottle is standing on top of this one -- which is the whole of what
-- `fitting = true` buys.
assert(t.target_at(2, 2, "connector_port") ~= nil, "a second port, in one action")
assert(#t.items_at(2, 2) == 0, "and no fitting was left lying about")
assert(t.pipe(2, 2) == 0 and t.pipe(2, 1) == 0, "with no run under it or beside it")

-- ---- an unplumbed socket is a socket, and it feeds the ROOM ----
--
-- The bottle fastens to it instantly (tg's `wrench_act` on a portable
-- has no do_after), and the connected picture goes on. What it is
-- connected TO is a different question, and the gas loop answers it
-- every pass off the live grid: no run under the stub, so the release
-- valve is pointed at the room -- exactly where it points when the
-- bottle is standing loose.
t.ui_close(p)
t.drop(p)
t.run_ticks(2)
t.swap_hands(p)
assert(t.hands(p).held == "wrench", "back to the wrench")

t.click(p, 2, 2, t.target_at(2, 2, "canister"))
t.run_ticks(2)
assert(
    t.ledger_has("StructureStep", "canister", "anchored"),
    "the bottle fastened to a port with no plumbing behind it"
)
assert(t.structure_at(2, 2).state == "anchored", "and reads as connected")

-- Dial the regulator over room pressure, which is the only way to make
-- a settled room legible: at the default setpoint a room already at one
-- atmosphere costs nothing, so any gas that moves now moved because a
-- player asked for it (canister_window_test.luau owns the knob).
t.swap_hands(p)
t.click(p, 2, 2, t.target_at(2, 2, "canister"))
t.tick()
t.ui_act(p, "set", '{"field":"release","value":400}')
t.tick()

local room_before = t.room_pressure(1, 1)
local can_before = t.canister_pressure(2, 2)
t.run_seconds(60)
local room_after = t.room_pressure(1, 1)
assert(
    room_after > room_before + 80.0,
    "an unplumbed socket puts the bottle's air in the ROOM: "
        .. room_before .. " -> " .. room_after
)
assert(
    t.canister_pressure(2, 2) < can_before - 50.0,
    "and the bottle is what paid: " .. t.canister_pressure(2, 2)
)
assert(t.pipe_pressure(2, 1) == nil, "there is still no run anywhere to have fed")

-- ---- and then the plumbing arrives ----
--
-- THE POINT OF THE WHOLE RULING. Nobody touches the port. Nobody
-- re-wrenches the bottle. A length of pipe is laid on the tile the
-- port's stub points at, and the binding appears because the gas loop
-- LOOKS rather than being told (`refresh_pipe_topology`, and the same
-- argument `sync_pipe_devices` is built on).
t.ui_close(p)
-- Still on the free hand -- the wrench is in the other one, and a
-- wrench swung at an RPD lying on the deck is not a pick-up.
t.click(p, 1, 2, t.target_at(1, 2, "rpd"))
t.run_ticks(2)
assert(t.hands(p).held == "rpd", "the RPD again")
t.use_self(p)
t.tick()
set(p, RECIPE, pick(p, RECIPE, "Pipe"))
t.click(p, 2, 1) -- one north of the port: the tile its stub reaches
work(p)
assert(t.pipe(2, 1) == 4, "a length on the distribution layer: " .. t.pipe(2, 1))

local room_at_lay = t.room_pressure(1, 1)
t.run_seconds(20)
assert(
    t.pipe_pressure(2, 1) > 150.0,
    "the port bound itself to the new run and the bottle charged it: "
        .. tostring(t.pipe_pressure(2, 1))
)
assert(
    math.abs(t.room_pressure(1, 1) - room_at_lay) < 5.0,
    "and the room stopped being the thing it fed: "
        .. room_at_lay .. " -> " .. t.room_pressure(1, 1)
)
