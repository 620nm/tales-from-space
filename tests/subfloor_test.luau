-- An intact floor tile hides its plumbing, and hiding it means hiding it
-- from tools as well as from eyes.
--
-- tg does this at the turf: `/turf/proc/levelupdate()` sends
-- COMSIG_OBJ_HIDE to everything standing in a covered tile
-- (code/game/turfs/turf.dm:503-506), which drops pipes, disposals and
-- wires to UNDERFLOOR_HIDDEN (code/__DEFINES/turfs.dm:50-54;
-- atmospherics registers for the signal in code/modules/atmospherics/
-- machinery/atmosmachinery.dm:135-145, `var/hide = TRUE` on line 38).
-- The rule is NOT "the tool declines" -- the buried thing is not there
-- to be clicked at all. So the wrench and the wirecutters answer a
-- covered tile with silence: no do_after, no ledger row, and above all
-- no message, because "you can't reach the pipe" would be a free survey
-- of what is buried under a station's floors.
--
-- Laying is the mirror case and speaks: you are placing something you
-- hold onto a floor you can see, so the refusal describes the floor and
-- gives nothing away.

local DISTRO = 4 -- piping layer 3
local ROOM = 1 -- the red line, the room circuit

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m:find(want, 1, true) then
            return true
        end
    end
    return false
end

-- (2, 1) is open plating and (2, 2) a finished floor tile; the same run
-- of pipe and the same branch cable pass under both. Every assertion
-- below is that pair answering differently. (2, 3) is a bare covered
-- tile, for the laying half.
t.world([==[(
    name: "subfloor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#.o.#",
        "#.o.#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 1, "wrench"),
        (3, 1, "wirecutters"),
        (1, 3, "cable_coil"),
        (3, 3, "crowbar"),
        (1, 2, "pipe"),
        (3, 2, "wrench"),
    ],
    pipes: [(2, 1, 4), (2, 2, 4)],
    cables: [(2, 1, 1, 0, 2), (2, 2, 1, 0, 1)],
)]==], 7)

local p = t.join()
t.tick()
assert(t.turf(2, 1) == "plating", "one tile is open")
assert(t.turf(2, 2) == "floor", "and its neighbour is tiled over")
assert(t.pipe(2, 2) == DISTRO, "the run passes under the tiled one")
assert(t.cable_at(2, 2) == ROOM, "and so does the cable")

-- ---------------------------------------------------------------
-- The wrench. Buried pipe under a tile is not wrenchable.
-- ---------------------------------------------------------------
t.click(p, 1, 1, t.target_at(1, 1, "wrench")) -- pick up the wrench
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")
local _ = t.messages(p)

t.click(p, 2, 2)
t.run_seconds(1.5)
assert(t.pipe(2, 2) == DISTRO, "the buried run is untouched")
assert(not said(p, "unwrenching"), "and the wrench never started on it")
assert(#t.ledger_rows("PipePulled") == 0, "nothing to put on the record")
assert(t.count_items("pipe") == 1, "no length came up (only the mapped one)")

-- The same click, one tile north where the deck is open, works. This is
-- what makes the silence above a rule about the floor and not a broken
-- hook.
t.click_subfloor(p, 2, 1, "pipe", DISTRO)
t.run_seconds(1.5)
assert(t.pipe(2, 1) == 0, "open plating gives the length up")
assert(#t.ledger_rows("PipePulled") == 1, "and that one IS on the record")
assert(t.count_items("pipe") == 2, "the removed length returned as a one-piece item")

-- ---------------------------------------------------------------
-- The wirecutters. Same rule, sabotage side.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(3, 1, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
_ = t.messages(p)

t.click(p, 2, 2)
t.run_seconds(1.5)
assert(t.cable_at(2, 2) == ROOM, "the buried cable is untouched")
assert(not said(p, "snipping"), "and the cutters never bit")
assert(#t.ledger_rows("CableCut") == 0, "no cut to attribute")

t.click_subfloor(p, 2, 1, "cable", ROOM, 0, 2)
t.run_seconds(1.5)
assert(t.cable_at(2, 1) == 0, "open plating cuts fine")
assert(#t.ledger_rows("CableCut") == 1, "and that cut is attributed")
assert(t.count_items("cable_coil") == 2, "the cut line returned as a one-piece coil")

-- ---------------------------------------------------------------
-- Laying, both trades: refused over a tile, and it says why.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 3, t.target_at(1, 3, "cable_coil")) -- the coil
t.run_ticks(2)
_ = t.messages(p)
t.click(p, 2, 3)
t.run_seconds(1.5)
assert(t.cable_at(2, 3) == 0, "no cable goes down over a finished floor")
assert(#t.ledger_rows("CableLaid") == 0, "nothing laid, nothing recorded")
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "and the refusal says what to do about it"
)

t.drop(p)
t.run_ticks(2)
t.click(p, 1, 2, t.target_at(1, 2, "pipe")) -- the length of pipe
t.run_ticks(2)
_ = t.messages(p)
t.click(p, 2, 3)
t.run_seconds(1.5)
assert(t.pipe(2, 3) == 0, "no length goes down over a finished floor either")
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "same instruction, same words"
)

-- ---------------------------------------------------------------
-- Pry the tile up and the plumbing is ordinary work again.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 3, t.target_at(3, 3, "crowbar")) -- the crowbar
t.run_ticks(2)
t.click(p, 2, 2)
t.run_ticks(2)
assert(t.turf(2, 2) == "plating", "the tile came up")

t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(3, 2, "wrench")) -- the spare wrench, kept clear of the pile at our feet
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand again")

t.click_subfloor(p, 2, 2, "pipe", DISTRO)
t.run_seconds(1.5)
assert(t.pipe(2, 2) == 0, "the same click that did nothing now pulls the run")
assert(#t.ledger_rows("PipePulled") == 2, "and the second pull is recorded")

-- ---------------------------------------------------------------
-- Covering open plumbing. The exact pixel the client picked does not
-- change the turf operation: floor tiles cover raw pipe and the
-- component which replaced a length of it, without deleting either.
-- ---------------------------------------------------------------
t.world([==[(
    name: "cover subfloor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "floor_tile")],
    pipes: [(1, 1, 4), (3, 2, 4)],
    structures: [(2, 1, "manual_valve"), (3, 1, "connector_port")],
)]==], 7)

local c = t.join()
t.tick()
t.click(c, 2, 2, t.target_at(2, 2, "floor_tile"))
t.run_ticks(2)
assert(t.hands(c).held == "floor_tile", "the tile stack is in hand")

-- A visible pipe has its own exact click channel. Material construction
-- still belongs to the turf underneath that sprite.
t.click_subfloor(c, 1, 1, "pipe", DISTRO)
t.run_seconds(2)
assert(t.turf(1, 1) == "floor", "a tile clicked on raw pipe covers the deck")
assert(t.pipe(1, 1) == DISTRO, "covering does not consume the raw pipe")

-- A binary machine is the length of pipe, and a unary connector is its
-- own centre plus a directional stub. Both are equally coverable when
-- the structure sprite itself was the exact target.
t.click(c, 2, 1, t.target_at(2, 1, "manual_valve"))
t.run_seconds(2)
assert(t.turf(2, 1) == "floor", "a floor tile covers a pipe device")
assert(t.structure_at(2, 1).id == "manual_valve", "the device remains under the tile")

t.click(c, 3, 1, t.target_at(3, 1, "connector_port"))
t.run_seconds(2)
assert(t.turf(3, 1) == "floor", "a floor tile covers a connector")
assert(t.structure_at(3, 1).id == "connector_port", "the connector remains under the tile")
assert(t.pipe(3, 1) == 0, "the unary connector still replaces its centre length")

-- The above cases clicked the plumbing art itself. A canister stacked over
-- its connector has transparent pixels around the bottle; those pixels name
-- ground, not whichever structure happens to be topmost on the tile. The
-- floor therefore slides over the port and under the still-fastened bottle.
t.world([==[(
    name: "tile under canister",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'c': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#.c.#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "floor_tile")],
    pipes: [(1, 1, 4)],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (2, 1, "connector_port"),
        (2, 1, "canister", { "air": "canister_air", "open": true }),
    ],
)]==], 7)

local d = t.join()
t.tick()
assert(t.target_at(2, 1, "connector_port") ~= nil, "a real port starts under the canister")
assert(t.canister_pressure(2, 1) > 4000.0, "the canister starts fastened and full")
assert(t.pipe_pressure(1, 1) > 90.0, "its port has charged the neighbouring run")
t.click(d, 2, 2, t.target_at(2, 2, "floor_tile"))
t.run_ticks(2)

-- Naming the native canister is naming the bottle, not its connector and
-- not the turf. It must not collapse into the ground operation below.
local bottle = t.target_at(2, 1)
assert(bottle ~= nil, "the visible canister has an exact wire identity")
t.click(d, 2, 1, bottle)
t.run_seconds(2)
assert(t.turf(2, 1) == "plating", "an explicit canister click leaves the deck open")
assert(t.canister_pressure(2, 1) ~= nil, "the named bottle and port remain intact")

-- No target is the alpha-tested deck pixel, even though a canister and port
-- share the logical tile.
t.click(d, 2, 1)
t.run_seconds(2)
assert(t.turf(2, 1) == "floor", "a ground pixel tiles beneath the canister")
assert(t.structure_at(2, 1).id == "canister", "the canister remains above the tile")
assert(t.canister_pressure(2, 1) ~= nil, "it remains anchored to its socket")
assert(t.pipe(2, 1) == 0, "the connector did not become a hidden raw length")
assert(t.pipe_pressure(1, 1) > 90.0, "the port remains plumbed to its neighbouring run")

-- ---------------------------------------------------------------
-- The open deck is a fact about the TILE, not about the letter its
-- turf is spelled with. A map may leave a panel open in a finished
-- floor and box the wiring in under bare plating (docs/MAPPING.md),
-- and every rule above follows the panel rather than the turf.
-- ---------------------------------------------------------------
t.world([==[(
    name: "authored decks",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor, subfloor: Some(Exposed)),
        'c': (turf: Plating, subfloor: Some(Concealed)),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#.oc#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "wirecutters")],
    cables: [(2, 1, 1, 0, 4), (3, 1, 1, 0, 8)],
)]==], 7)

local e = t.join()
t.tick()
assert(t.turf(2, 1) == "floor", "the panel is a finished floor")
assert(t.subfloor_exposed(2, 1), "and its deck is open anyway")
assert(t.turf(3, 1) == "plating", "its neighbour is bare plating")
assert(not t.subfloor_exposed(3, 1), "with its wiring boxed in")

t.click(e, 2, 2, t.target_at(2, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(e).held == "wirecutters", "cutters in hand")
_ = t.messages(e)

t.click_subfloor(e, 3, 1, "cable", ROOM, 0, 8)
t.run_seconds(1.5)
assert(t.cable_at(3, 1) == ROOM, "boxed-in plating keeps its run")
assert(not said(e, "snipping"), "and the cutters never bit")

t.click_subfloor(e, 2, 1, "cable", ROOM, 0, 4)
t.run_seconds(1.5)
assert(t.cable_at(2, 1) == 0, "the open panel gives its run up")
assert(t.turf(2, 1) == "floor", "without becoming a different deck")
