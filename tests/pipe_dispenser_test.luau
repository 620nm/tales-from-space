-- The pipe dispenser: free fittings onto its own tile, one per second,
-- and a bin for the ones you did not need.
--
-- It is the same engine machine the softdrinks vendor is — the window,
-- the act, the hostile-ref refusal are all shared — so what this spec
-- is actually about is the three things a DISPENSER does that a vendor
-- does not: it stocks the atmospherics kit, it waits a second between
-- handouts, and it swallows what it handed out.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function on_tile(x, y, id)
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

t.world([==[(
    name: "atmos annex",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "wrench")],
    machines: [(2, 1, "pipe_dispenser")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- ---- the window ----
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking the dispenser opens its window")
assert(ui.document == "modules" and ui.presentation == "shelf",
    "the shared shelf document")

-- tg's recipe categories, by tg's own names
-- (code/_globalvars/lists/pipe_recipes.dm). All four are stocked now
-- that the plate heat exchanger exists — a tab exists exactly when
-- something on it does.
local shelf = {}
local cats = {}
for _, rec in ipairs(ui.products) do
    shelf[rec.payload.product] = rec
    cats[rec.category] = true
end
assert(cats.Pipes and cats.Binary and cats.Devices, "three of tg's four categories")
assert(cats["Heat Exchange"], "and the fourth, now that a plate lives on it")
assert(shelf.pump_fitting.category == "Binary", "a pump is binary")
assert(shelf.pump_fitting.label == "Pump", "listed by the MACHINE's name")
assert(shelf.pipe_meter.category == "Devices", "the meter is a device")
assert(shelf.mixer_flipped_fitting, "both mirror images are on the shelf")
assert(shelf.pipe.category == "Pipes", "and plain pipe leads")
-- The two vents, which are the commonest thing an engineer comes here
-- for: every room the crew stands in wants one, and both are ordinary
-- fittings you carry away and bolt down.
assert(shelf.vent_fitting.label == "Air Vent", "a vent is stocked like any other machine")
assert(shelf.vent_fitting.category == "Devices", "on the shelf with the other room devices")
assert(shelf.passive_vent_fitting.label == "Passive Vent", "and so is its unpowered twin")
assert(shelf.cola == nil, "a pipe dispenser sells no softdrinks")

-- ---- it dispenses onto its OWN tile, free ----
--
-- tg's `new /obj/item/pipe(loc)` (pipe_dispenser.dm:209): out of the
-- machine, onto the machine. The buyer bends down for it.
assert(t.count_items("pump_fitting") == 0)
t.ui_act(p, "vend", '{"product":"pump_fitting"}')
t.tick()
assert(t.count_items("pump_fitting") == 1, "the named fitting dispensed")
assert(on_tile(2, 1, "pump_fitting"), "onto the dispenser's tile, not the buyer's")
assert(t.ledger_has("ItemSpawned", "pump_fitting", "Player"),
    "a UI act is a direct player action")

-- ---- and then it waits ----
--
-- tg's `wait = world.time + 1 SECONDS` (pipe_dispenser.dm:213). Two
-- presses in the same breath are one fitting; the second press is not
-- queued, it is dropped, so the button is worth exactly as much to a
-- script as to a finger.
t.ui_act(p, "vend", '{"product":"pump_fitting"}')
t.ui_act(p, "vend", '{"product":"manual_valve_fitting"}')
t.tick()
assert(t.count_items("pump_fitting") == 1, "the second press inside the second is dropped")
assert(t.count_items("manual_valve_fitting") == 0, "and so is a press for something else")

t.run_seconds(1)
t.ui_act(p, "vend", '{"product":"manual_valve_fitting"}')
t.tick()
assert(t.count_items("manual_valve_fitting") == 1, "a second later it hands out again")

-- NEGATIVE: the client is hostile. A ref this machine does not stock
-- mints nothing — not a fallback, and certainly not an arbitrary
-- prototype named by the payload.
t.run_seconds(1)
t.ui_act(p, "vend", '{"product":"id_captain"}')
t.tick()
assert(t.count_items("id_captain") == 0, "no dispenser can be talked into minting an ID card")

-- ---- recycling: it takes back what it hands out ----
--
-- tg's `item_interaction` (pipe_dispenser.dm:154-160): the fitting is
-- deleted and nothing is refunded, because the machine never had stock
-- to return it to.
--
-- The tile has to be cleared first, and that is not a test artefact —
-- a dispenser drops its stock at its own feet, so a click on that tile
-- names the pile before it names the machine, exactly as it would in
-- tg. You pick your fittings up and then the machine is clickable.
t.ui_close(p)
t.click(p, 2, 1, t.target_at(2, 1, "manual_valve_fitting"))
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "pump_fitting"))
t.run_ticks(2)
local hands = t.hands(p)
assert(hands.held == "manual_valve_fitting", "the valve fitting is in the working hand")
assert(hands[2] == "pump_fitting", "and the pump fitting in the other")
assert(#t.items_at(2, 1) == 0, "the dispenser's tile is clear again")

local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1))
t.run_ticks(2)
assert(t.hands(p).held == nil, "the dispenser swallowed what was in the working hand")
assert(t.hands(p)[2] == "pump_fitting", "and left the other hand alone")
assert(#t.items_at(2, 1) == 0, "nothing was refunded onto the deck")
assert(said(p, "You put the manual valve fitting back into the dispenser."),
    "and said so, in the fitting's own name")
-- On the record, and the record names both halves: the machine's own
-- file did it, at the request of the crewman standing there.
assert(t.ledger_has("ItemConsumed", "manual_valve_fitting", "pipe_dispenser"),
    "a thing that stopped existing is on the record")
local eaten = t.ledger_rows("item_consumed")
assert(#eaten == 1 and eaten[1].actor.kind == "script", "one row, attributed to the machine")
assert(eaten[1].actor.triggered_by, "and it names who asked")

-- NEGATIVE: it takes back its OWN kit and nothing else. A wrench is a
-- tool, not stock, and a machine that ate an engineer's wrench because
-- they clicked the wrong tile would be a griefing device.
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in the working hand")
t.click(p, 2, 1, t.target_at(2, 1))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "the dispenser does not deal in wrenches")
assert(not t.ledger_has("ItemConsumed", "wrench"), "and wrote no row about one")
