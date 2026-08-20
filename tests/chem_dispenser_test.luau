-- The chem dispenser, from the outside: a beaker goes in, a button
-- fills it, and the machine will not put in more than the beaker holds.
--
-- Everything here is a click or a window act, which are the two
-- surfaces a crewman actually has. The important one is the LEDGER: a
-- dispenser is the only machine on the bench that conjures matter, so
-- the row it leaves behind is what makes the moles accountable.
-- tg's `amount = 30` through the documented unit bridge, and its
-- `dispensed_temperature` (chem_dispenser.dm:18,22).
local PRESS = 0.75
local NOZZLE_K = 300.0
-- 50 u at 1 u = 0.025 mol (items/beaker.luau).
local BRIM = 1.25

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

local function total(handle)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    local n = 0
    for _, moles in pairs(contents) do
        n = n + moles
    end
    return n
end

t.world([==[(
    name: "chem bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "beaker")],
    machines: [(2, 1, "chem_dispenser")],
)]==], 0)

local p = t.join()
t.tick()

local machine = t.target_at(2, 1)
assert(machine ~= nil, "a dispenser stands on the bench")
local beaker = t.target_at(1, 1, "beaker")

-- ---------------------------------------------------------------
-- AN EMPTY HAND ASKS; A FULL ONE LOADS.
-- ---------------------------------------------------------------
t.click(p, 2, 1, machine)
t.tick()
local ui = t.ui(p)
assert(ui, "an empty hand opens the panel")
assert(ui.kind == "chem_dispenser", "which is this machine's own")
assert(row(ui, "vessel").value == "empty", "and it says there is nothing in it")
near(row(ui, "measure").value:gsub(" mol", "") + 0, PRESS, 1e-9, "one press, in moles")

-- The shelf is the machine's own file, and the panel IS the whitelist:
-- every button on it names something the registry answered to.
local buttons = {}
for _, toggle in ipairs(ui.toggles) do
    if toggle.field == "dispense" then
        buttons[toggle.option] = toggle
    end
end
assert(buttons.sodium ~= nil, "sodium is on the shelf")
assert(buttons.o2 ~= nil, "and so is the station's own oxygen")
assert(buttons.sodium.on == false, "a dispense button never latches")
assert(
    buttons.sodium.on_text == buttons.sodium.off_text,
    "it says the same thing in both positions, because it has only one"
)
t.ui_close(p)

t.click(p, 1, 1, beaker)
t.tick()
assert(t.hands(p).held == "beaker", "the beaker is in hand")
near(total(beaker), 0, 1e-9, "and it ships empty off the shelf")

t.click(p, 2, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "clicking the dispenser with it puts it IN")
assert(t.ledger_has("Docked", "beaker"), "the dock is on the record")

-- ---------------------------------------------------------------
-- ONE PRESS IS ONE PRESS.
-- ---------------------------------------------------------------
t.click(p, 2, 1, machine)
t.tick()
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
near(t.contents(beaker).water, PRESS, 1e-9, "one press is tg's 30 u")
near(t.holder_k(beaker), NOZZLE_K, 0.01, "arriving at the nozzle's own temperature")
assert(row(t.ui(p), "contents").value == "0.75 / 1.25 mol", "and the panel says so")

-- ---------------------------------------------------------------
-- ...AND A PRESS INTO A NEARLY-FULL BEAKER IS TRIMMED, NOT REFUSED.
--
-- tg's own policy on the same gesture (chem_dispenser.dm:305), and the
-- one a pour already follows: take what fits and leave the rest.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
near(total(beaker), BRIM, 1e-9, "the second press stopped at the brim")

-- Full to the brim, a press does nothing at all -- and a refusal is not
-- a mint of zero, so it leaves no row behind.
local before = #t.ledger_rows("dispensed")
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
near(total(beaker), BRIM, 1e-9, "nothing more fits")
assert(#t.ledger_rows("dispensed") == before, "and nothing was written down")

-- ---------------------------------------------------------------
-- THE AUDIT.
--
-- What the beaker holds is the sum of the rows that put it there. This
-- is the whole reason a machine that can conjure matter has to be on
-- the record at all.
-- ---------------------------------------------------------------
local rows = t.ledger_rows("dispensed")
assert(#rows == 2, "two presses landed: " .. #rows)
local minted = 0
for _, r in ipairs(rows) do
    minted = minted + r.moles
    assert(r.substance == "water", "the row names the substance: " .. r.substance)
    assert(r.actor.kind == "player", "and the crewman who pressed the button")
end
near(minted, total(beaker), 1e-9, "every mole in the beaker has a row behind it")

-- ---------------------------------------------------------------
-- AND YOU GET IT BACK.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the eject button hands it back")
near(total(beaker), BRIM, 1e-9, "still holding what it was given")
assert(t.ledger_has("Undocked", "beaker"), "and the eject is on the record too")
assert(row(t.ui(p), "vessel").value == "empty", "the panel agrees the slot is clear")

-- A press with nothing in the slot mints nothing, anywhere: a
-- dispenser that puddled on the floor instead would be a second
-- deposit path nobody asked for.
before = #t.ledger_rows("dispensed")
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
assert(#t.ledger_rows("dispensed") == before, "an empty dock dispenses nothing")

-- ...and neither does a button this machine does not have. The shelf is
-- fourteen substances; the registry knows dozens.
t.click(p, 2, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "the beaker goes back in")
t.click(p, 2, 1, machine)
t.tick()
t.ui_act(p, "toggle", '{"field":"dispense","option":"plasma"}')
t.run_ticks(2)
near(total(beaker), BRIM, 1e-9, "a substance that is real but not stocked is not a button")
