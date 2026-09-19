local composition = require("@helpers/composition")

local network_matter = require("@helpers/network_matter")
local ui_controls = require("@helpers/ui_controls")

-- The pipe painter, and what a stripe of the wrong colour costs.
--
-- tg's `is_connectable` refuses two pipe ends whose paint disagrees
-- unless one of them is omni grey
-- (code/modules/atmospherics/machinery/atmosmachinery.dm:335-354). That
-- makes a paint job plumbing rather than labelling: a technician can cut
-- a live distribution main with a brush, and the line still looks whole.
--
-- So this spec does not assert that a colour was written down. It
-- asserts that the gas stopped arriving.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function heard(p, name)
    for _, s in ipairs(t.sounds(p)) do
        if s == name then
            return true
        end
    end
    return false
end

-- One step, plus the move cooldown (lunatic_core::MOVE_COOLDOWN_TICKS
-- is 4), so two calls in a row are two steps.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- ---------------------------------------------------------------
-- A supply main painted blue end to end, a canister on a connector
-- port at the west end, and a vent blowing the east end into open
-- space. The bottle pays for everything the vent throws away, which is
-- what makes "the canister stopped draining" a proof that the line
-- stopped carrying.
--
-- The deck is open over the run (pipe is subfloor infrastructure and
-- you cannot paint what you cannot see) except at (6, 1), which is
-- tiled — that one is here to be refused.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "painter",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'F': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'c': (composition: (components: [(component: "station_base")])),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    rows: [
        "########  ",
        "#c....F#. ",
        "#aoooog#  ",
        "########  ",
    ],
    items: [(1, 2, "pipe_painter")],
    networks: [
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15, paint: Some("blue")),
        (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15, paint: Some("blue")),
        (x: 4, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15, paint: Some("blue")),
        (x: 5, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15, paint: Some("blue")),
        (x: 6, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15, paint: Some("blue")),
        (x: 7, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15, paint: Some("blue")),
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],

    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (1, 2, "player_spawn"),
        (1, 1, "connector_port"), (8, 1, "vent"),
        (1, 1, "canister", { "blend": "canister_air", "open": true }),
        (1, 2, "apc"),
    ],

)]==],
    7
)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(p, 1, 2, "pipe_painter"))
t.run_ticks(2)
assert(t.hands(p).held == "pipe_painter", "painter in hand")

-- Let the bottle, the line and the hole outside find their standoff.
t.run_seconds(10)

-- ---- one colour, one net ----
--
-- Six lengths in one blue line are ONE body of gas, so both ends read
-- the same number to the last decimal: they are literally the same
-- cell. That equality is what the rest of this spec breaks.
local west = assert(network_matter.pressure(2, 1))
local east = assert(network_matter.pressure(7, 1))
assert(math.abs(west - east) < 0.01, "one painted run is one pipenet: " .. west .. " vs " .. east)

-- And the bottle is paying for the vent at the far end of it.
local opening = assert(t.canister_pressure(1, 1))
t.run_seconds(10)
local spent = opening - assert(t.canister_pressure(1, 1))
assert(spent > 100.0, "the canister feeds the line: " .. spent .. " kPa spent")

-- ---- the dial ----
--
-- tg picks the colour off a list prompt; we have no list, so the dial
-- cycles on the in-hand key the way a length of pipe's layer does.
-- Omni, green, blue, then red — tg's own roster order.
local _ = t.messages(p)
t.use_self(p)
t.use_self(p)
t.use_self(p)
t.run_ticks(2)
assert(said(p, "Pipe painter set to red."), "three clicks along tg's roster")

-- Empty or covered deck offers no painting action.
walk(p, "east")
walk(p, "east")
walk(p, "east")
walk(p, "east")
local _ = t.messages(p)
for _, y in ipairs({ 1, 2 }) do
    for _, action in ipairs(t.action_hints(p, composition.deck_target(6, y))) do
        assert(action.id ~= "paint_pipe", "painting needs a visible run")
    end
end
t.click(p, 6, 2) -- open deck, no run under it
t.run_ticks(2)
assert(
    not said(p, "There is no pipe under the floor here."),
    "bare deck does not invoke the painter"
)
assert(not t.ledger_has("NetworkPainted"), "and writes no row")

-- ...and neither is painting through a floor you have not opened.
t.click(p, 6, 1) -- tiled, with the run buried under it
t.run_ticks(2)
assert(
    not said(p, "The floor is in the way. Pry the tile up first."),
    "you cannot paint a run you cannot see"
)
assert(not t.ledger_has("NetworkPainted"), "still no row")
assert(network_matter.pressure(2, 1) == assert(network_matter.pressure(7, 1)), "and still one net")

-- ---- **the headline**: a brush cuts the main ----
t.click(p, 5, 1)
t.run_ticks(2)
assert(said(p, "You paint the pipe red."), "one length changes colour")
assert(heard(p, "click"), "and the room hears it happen")

local rows = t.ledger_rows("network_painted")
assert(#rows == 1, "one act, one row: " .. #rows)
local painted_target = ui_controls.record(rows[1].target)
local at = ui_controls.record(painted_target.tile)
assert(at.x == 5 and at.y == 1, "which tile")
assert(painted_target.instance == t.network_instance(5, 1, "pipe", "l3"), "which retained pipe")
assert(rows[1].paint == "red", "and which authored colour, so the record can say")

-- The line is intact. Nothing was cut, nothing was welded, the deck is
-- exactly as it was — and the two ends of it are now two networks.
t.run_seconds(10)
local fed = assert(network_matter.pressure(2, 1))
local starved = assert(network_matter.pressure(7, 1))
assert(fed > 90.0, "the bottle's half filled to its setpoint: " .. fed)
assert(starved < 10.0, "and the vent's half emptied into space: " .. starved)

-- The bookkeeping half of the same fact: with nowhere left to send it,
-- the canister has stopped spending. (Measured after the near half has
-- filled, so what is left is the flat line and not the filling.)
local settled = assert(t.canister_pressure(1, 1))
t.run_seconds(10)
local trickle = settled - assert(t.canister_pressure(1, 1))
assert(trickle < 2.0, "a severed main draws nothing: " .. trickle .. " kPa")

-- ---- and paints it back ----
--
-- Blue again. Two nets become one through the same conserving rebuild
-- that split them, the vent's half is fed once more, and the bottle
-- goes back to paying for it.
local _ = t.messages(p)
t.use_self(p) -- red -> orange
t.use_self(p) -- orange -> cyan
t.use_self(p) -- cyan -> dark
t.use_self(p) -- dark -> yellow
t.use_self(p) -- yellow -> brown
t.use_self(p) -- brown -> pink
t.use_self(p) -- pink -> purple
t.use_self(p) -- purple -> violet
t.use_self(p) -- violet -> white
t.use_self(p) -- white -> omni (the roster wraps)
t.use_self(p) -- omni -> green
t.use_self(p) -- green -> blue
t.run_ticks(2)
assert(said(p, "Pipe painter set to blue."), "the roster wraps, thirteen long")

t.click(p, 5, 1)
t.run_ticks(2)
assert(said(p, "You paint the pipe blue."), "the stripe comes out")
t.run_seconds(10)

local rejoined_west = assert(network_matter.pressure(2, 1))
local rejoined_east = assert(network_matter.pressure(7, 1))
assert(
    math.abs(rejoined_west - rejoined_east) < 0.01,
    "one line again: " .. rejoined_west .. " vs " .. rejoined_east
)

local resumed = assert(t.canister_pressure(1, 1))
t.run_seconds(10)
local paying = resumed - assert(t.canister_pressure(1, 1))
assert(paying > 100.0, "and the bottle is paying for the hole again: " .. paying)

-- Two acts, two rows. The record can name who cut the main and who put
-- it back, which is the whole reason paint earns rows at all.
assert(#t.ledger_rows("network_painted") == 2, "both acts on the record")
