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
-- The DIAL's ceiling: 50 u at 1 u = 0.025 mol, off
-- machines/chem_dispenser.luau. It is what the machine will hand over
-- in one press, and no longer a statement about the beaker.
local DIAL_MAX = 1.25
-- What the BEAKER holds, which is geometry and nothing else
-- (docs/MATTER.md 5): fifty millilitres of glass over water's
-- 18.015 mL to the mole.
local BRIM = 50e-6 / 18.015e-6
-- The dial over the press, off machines/chem_dispenser.luau: one tg
-- unit at the bottom and a notch, a beaker's brim at the top.
local NOTCH = 0.025

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

-- The contents block: what the docked vessel is HOLDING, by state
-- (docs/tgui/matter-block.md).
local function block(ui, section)
    for _, b in ipairs(ui.matter or {}) do
        if b.section == section then
            return b
        end
    end
    return nil
end

local function state(b, phase)
    for _, st in ipairs(b and b.states or {}) do
        if st.phase == phase then
            return st
        end
    end
    return nil
end

local function dial(ui, field)
    for _, s in ipairs(ui.setpoints) do
        if s.field == field then
            return s
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
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "#####",
        "#o.a#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "beaker"), (1, 1, "bottle")],
    machines: [(2, 1, "chem_dispenser")],
    cables: [
        (1, 1, 1), (2, 1, 1), (3, 1, 1),
    ],
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
assert(ui.document == "modules", "which is a clean-room module document")
assert(row(ui, "vessel").value == "empty", "and it says there is nothing in it")

-- The measure is a DIAL, not a reading: a chemist who wants half a
-- beaker turns it down rather than pressing and pouring back.
local measure = dial(ui, "amount")
assert(measure ~= nil, "the panel offers an amount to dispense")
near(measure.value, PRESS, 1e-9, "opening at tg's 30 u")
near(measure.min, NOTCH, 1e-9, "one tg unit at the bottom")
near(measure.max, DIAL_MAX, 1e-9, "and tg's 50 u at the top")
near(measure.step, NOTCH, 1e-9, "a notch is one tg unit")
assert(measure.unit == "mol", "in the units the contents are counted in")

-- The shelf is the machine's own file, and the panel IS the whitelist:
-- every button on it names something the registry answered to.
local buttons = {}
for _, toggle in ipairs(ui.toggles) do
    if toggle.field == "dispense" then
        buttons[toggle.option] = toggle
    end
end
assert(buttons.sodium ~= nil, "sodium is on the shelf")
assert(buttons.chlorine ~= nil, "and so is chlorine, which needs a lid")
assert(buttons.o2 == nil, "the permanent gases are not: they come off canisters (D19)")
assert(buttons.n2 == nil, "neither of them")
assert(buttons.hydrogen == nil, "nor hydrogen")
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
-- A tenth of a kelvin of slack: what lands is settled on the spot
-- (sim/owner.rs, `deposit_into`), so the first thing the water does is
-- evaporate into thirty-six millilitres of empty glass and carry a
-- little latent heat with it.
near(t.holder_k(beaker), NOZZLE_K, 0.1, "arriving at the nozzle's own temperature")
-- The panel counts the GLASS, in litres: 0.75 mol of water is 13.5 mL
-- of a fifty millilitre beaker (docs/MATTER.md 5). Capacity is
-- geometry, so what a crewman reads is the level against the shell.
local glass = block(t.ui(p), "contents")
near(state(glass, "liquid").measure, 0.0135, 1e-4, "the level in the vessel")
near(glass.volume_l, 0.05, 1e-9, "against the size of the glass")

-- ---------------------------------------------------------------
-- ...AND A PRESS INTO A NEARLY-FULL BEAKER IS TRIMMED, NOT REFUSED.
--
-- tg's own policy on the same gesture (chem_dispenser.dm:305), and the
-- one a pour already follows: take what fits and leave the rest.
-- ---------------------------------------------------------------
-- Three more presses of 30 u is 3.0 mol asked for and 54 mL of water
-- wanted, which is four millilitres more glass than there is.
for _ = 1, 3 do
    t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
    t.run_ticks(2)
end
near(total(beaker), BRIM, 1e-9, "the last press stopped at the brim")

-- Full to the brim, a press is not a press. What room a brim-full
-- glass has is what its own surface has evaporated into the air above
-- it -- micromoles, and a rounding error rather than a dose.
local before = #t.ledger_rows("minted")
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
near(total(beaker), BRIM, 1e-5, "nothing you could measure fits")
local after = t.ledger_rows("minted")
assert(#after <= before + 1, "at most one row, and it is not a press")
if #after > before then
    assert(after[#after].moles < 1e-5,
        "a rounding error, not a dose: " .. after[#after].moles)
end

-- ---------------------------------------------------------------
-- THE AUDIT.
--
-- What the beaker holds is the sum of the rows that put it there. This
-- is the whole reason a machine that can conjure matter has to be on
-- the record at all.
-- ---------------------------------------------------------------
local rows = t.ledger_rows("minted")
-- Four presses, and a fifth row only if the brim-full press above
-- found its rounding error's worth of room.
assert(#rows == 4 or #rows == 5, "four presses landed: " .. #rows)
local minted = 0
for _, r in ipairs(rows) do
    minted = minted + r.moles
    assert(r.substance == "water", "the row names the substance: " .. r.substance)
    assert(r.actor.kind == "player", "and the crewman who pressed the button")
end
-- Every mole in the glass has a row behind it, and the rows come to a
-- hair MORE than the glass holds: an open beaker breathes its own
-- vapour into the room (sim/holder/vent.rs), so what evaporated away
-- is the difference and nothing else is.
assert(minted >= total(beaker) - 1e-9,
    "nothing is in the beaker that was not minted: " .. minted)
near(minted, total(beaker), 1e-4, "every mole in the beaker has a row behind it")

-- ---------------------------------------------------------------
-- AND YOU GET IT BACK.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the eject button hands it back")
near(total(beaker), BRIM, 1e-5, "still holding what it was given")
assert(t.ledger_has("Undocked", "beaker"), "and the eject is on the record too")
assert(row(t.ui(p), "vessel").value == "empty", "the panel agrees the slot is clear")

-- A press with nothing in the slot mints nothing, anywhere: a
-- dispenser that puddled on the floor instead would be a second
-- deposit path nobody asked for.
before = #t.ledger_rows("minted")
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
assert(#t.ledger_rows("minted") == before, "an empty dock dispenses nothing")

-- ...and neither does a button this machine does not have. The shelf is
-- sixteen substances; the registry knows dozens.
t.click(p, 2, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "the beaker goes back in")
t.click(p, 2, 1, machine)
t.tick()
t.ui_act(p, "toggle", '{"field":"dispense","option":"plasma"}')
t.run_ticks(2)
near(total(beaker), BRIM, 1e-5, "a substance that is real but not stocked is not a button")

-- ---------------------------------------------------------------
-- THE DISPOSAL: A BEAKER YOU FILLED WRONG.
--
-- tg's ChemMaster empties a beaker by transferring its reagents to
-- nowhere (`transfer_reagent` with `is_transfering = FALSE`,
-- chem_master.dm), and this is that verb at the machine where a chemist
-- actually discovers the mistake. It DESTROYS, so the row is the whole
-- of the accounting: without it, a shift's moles would simply stop
-- adding up.
-- ---------------------------------------------------------------
local held = total(beaker)
near(held, BRIM, 1e-5, "the beaker is still full of the wrong thing")

t.ui_act(p, "toggle", '{"field":"empty"}')
t.run_ticks(2)
near(total(beaker), 0, 1e-9, "and one press empties it")
assert(t.hands(p).held == nil, "the vessel stays in the machine")

local flushed = t.ledger_rows("Annihilated")
assert(#flushed == 1, "one press is one row: " .. #flushed)
near(flushed[1].moles, held, 1e-9, "carrying every mole that was destroyed")
assert(flushed[1].owner == "beaker", "and naming the vessel: " .. flushed[1].owner)
assert(flushed[1].actor.kind == "player", "a window act is the crewman acting")

-- Pressing it again is a refusal in silence: there is nothing to
-- destroy, and a row saying zero moles went nowhere is not a record of
-- anything.
t.ui_act(p, "toggle", '{"field":"empty"}')
t.run_ticks(2)
assert(#t.ledger_rows("Annihilated") == 1, "an empty vessel flushes nothing")

-- ---------------------------------------------------------------
-- THE DIAL: THE NEXT PRESS IS THE ONE YOU ASKED FOR.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"amount","value":0.25}')
t.run_ticks(2)
near(dial(t.ui(p), "amount").value, 0.25, 1e-9, "the dial took the number")
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
-- A tenth of a millimole of slack: the vessel settles as it fills
-- (sim/owner.rs, `deposit_into`), so a whisker of what landed is
-- already vapour on its way to the room.
near(total(beaker), 0.25, 1e-3, "and the press is what the dial says")
near(t.holder_k(beaker), NOZZLE_K, 0.3, "still off the same nozzle")

-- A smaller press is still a full row, so the audit holds at any
-- setting: what the beaker holds is the sum of what was minted into it.
local minted = 0
for _, r in ipairs(t.ledger_rows("minted")) do
    if r.substance == "water" then
        minted = minted + r.moles
    end
end
near(minted, BRIM + 0.25, 1e-4, "every mole ever minted has a row, flushed or not")

-- ---------------------------------------------------------------
-- ...AND THE ENDS ARE THE MACHINE'S, NOT THE CLIENT'S.
--
-- The window IS the whitelist (sim/ui/settings.rs): a number outside
-- the bounds this panel declared comes back clamped rather than obeyed,
-- and the row on the record is the number the machine ACCEPTED.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"amount","value":99}')
t.run_ticks(2)
near(dial(t.ui(p), "amount").value, DIAL_MAX, 1e-9, "past the top is the top")
t.ui_act(p, "set", '{"field":"amount","value":-5}')
t.run_ticks(2)
near(dial(t.ui(p), "amount").value, NOTCH, 1e-9, "under the bottom is the bottom")

local knobs = t.ledger_rows("machine_setpoint")
local turns = 0
for _, r in ipairs(knobs) do
    if r.field == "amount" then
        turns = turns + 1
        assert(r.unit == "mol", "the row says what the number is in")
        assert(r.value >= NOTCH and r.value <= DIAL_MAX, "post-clamp: " .. r.value)
    end
end
assert(turns == 3, "three turns of the dial are three rows: " .. turns)

-- ---------------------------------------------------------------
-- THE NOZZLE CHOOSES NO PHASE.
--
-- A dispenser used to declare one phase for its whole shelf and mint
-- everything as that, which made liquid oxygen out of a button. It
-- declares only a TEMPERATURE now: what lands is what the substance IS
-- at 300 K and one atmosphere, off the registry (docs/MATTER.md).
--
-- Water is the easy half -- 300 K is well under its boiling point, so a
-- press of water is water in the glass.
-- ---------------------------------------------------------------
local reading = t.vessel(beaker)
assert(reading ~= nil, "the beaker reads")
near(reading.contents.water.liquid, 0.25, 1e-3, "a press of water is a liquid")
assert((reading.contents.water.gas or 0) < 1e-3, "with only its own vapour over it")
near(reading.temp_k, NOZZLE_K, 0.3, "at the nozzle's temperature")

-- ...and chlorine is the other half. At 300 K it is a GAS, and a gas
-- over an open beaker is a press with nothing to show for it: what
-- landed would leave through the same mouth before the chemist looked
-- up. The machine refuses, says why, and writes no row -- nothing was
-- minted, so there is nothing to account for.
local _ = t.messages(p)
before = #t.ledger_rows("minted")
t.ui_act(p, "toggle", '{"field":"dispense","option":"chlorine"}')
t.run_ticks(2)
near(total(beaker) - 0.25, 0, 1e-3, "an open glass takes none of it")
assert(#t.ledger_rows("minted") == before, "and nothing is on the record")
assert(
    said(p, "That would only escape: seal a vessel first."),
    "the machine says why rather than doing nothing in silence"
)

-- ---------------------------------------------------------------
-- ...AND THE SAME PRESS INTO A BOTTLE IS THE USEFUL GESTURE.
--
-- A lid is the whole difference. Chlorine minted into a sealed vessel
-- has nowhere to escape to, so what was refused over a beaker lands
-- here and stays: a quarter of a mole in fifty millilitres, pressing
-- on the cork.
--
-- What it does NEXT is the sweep's, not the nozzle's, and it is the
-- most violent thing on this bench. A quarter mole of gas in 50 mL is
-- a hundred and twenty atmospheres; chlorine's saturation line puts
-- it at eight (substances/chlorine.luau), so most of that press has to
-- become liquid. Condensing is ADIABATIC -- `change_phase` moves
-- moles and leaves `energy_j` alone, and the b offsets hand the latent
-- heat to whatever is in the vessel (docs/MATTER.md 5). What is in the
-- vessel is a quarter mole of chlorine, 8.5 J/K of it, against 20.4 kJ
-- for every mole that condenses. The bottle does not stay at the
-- nozzle's 300 K: it climbs a hundred and sixty kelvin, and it stops
-- climbing exactly where the line catches up with the pressure it has
-- built.
-- ---------------------------------------------------------------
-- Chlorine's own numbers, off substances/chlorine.luau, so the assertions
-- below say the physics rather than a number somebody measured once.
local CHLORINE_L_VAP = 20410.0
local CHLORINE_BOIL_K = 239.1
local CHLORINE_CV = 33.9

-- The Clausius-Clapeyron line of record: one atmosphere at the
-- 239.1 K boiling point, k = -L_vap/R (docs/MATTER.md 5, Appendix A of
-- the milestone spec). About 8 atm at 300 K, and Appendix B's
-- reference is 6.6 atm at 293 K.
local function chlorine_line_kpa(temp_k)
    return 101.325 * math.exp((-CHLORINE_L_VAP / 8.314) * (1.0 / temp_k - 1.0 / CHLORINE_BOIL_K))
end

t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
t.drop(p)
t.tick()

local bottle = t.target_at(1, 1, "bottle")
assert(bottle ~= nil, "a bottle is standing on the bench")
t.click(p, 1, 1, bottle)
t.tick()
assert(t.hands(p).held == "bottle", "the bottle is in hand")
t.click(p, 2, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "and it goes into the dock")
t.click(p, 2, 1, machine)
t.tick()
t.ui_act(p, "set", '{"field":"amount","value":0.25}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"dispense","option":"chlorine"}')
-- The press lands in one pass; the sweep takes a few more to walk the
-- superheat down onto the line, and a docked vessel is insulated from
-- the deck (sim/holder/heat.rs) so nothing else is touching it.
t.run_seconds(20)

local bottled = t.vessel(bottle)
assert(bottled.sealed, "a bottle has a stopper in it")
assert(bottled.contents.chlorine ~= nil, "and this time the press landed")
near(bottled.moles, 0.25, 1e-6, "the whole press went in this time")
local condensed = bottled.contents.chlorine.liquid or 0
assert(condensed > 0, "and most of it is standing in the bottle as LIQUID chlorine")
assert((bottled.contents.chlorine.gas or 0) > 0, "with the rest of it over the top")

-- The closed form, and the reason a chemist should be careful with
-- that button: every mole that condenses hands 20.4 kJ to a mixture
-- whose whole heat capacity is 0.25 x 33.9 = 8.5 J/K.
near(
    bottled.temp_k,
    NOZZLE_K + condensed * CHLORINE_L_VAP / (0.25 * CHLORINE_CV),
    1.0,
    "the latent heat of what condensed is where the temperature went"
)
assert(bottled.temp_k > NOZZLE_K + 150.0, "which is a long way over the nozzle: " .. bottled.temp_k)
-- ...and it stopped there because that is where the line is. The gauge
-- and the temperature are one statement, not two.
near(
    bottled.pressure_kpa,
    chlorine_line_kpa(bottled.temp_k),
    20.0,
    "the gauge is that temperature's own vapour pressure"
)
assert(t.ledger_has("Minted", "bottle"), "and the mint is on the record")

-- ---------------------------------------------------------------
-- ...AND THEN THE DECK TAKES IT BACK.
--
-- A vessel standing loose on the floor exchanges heat with the tile it
-- is on, both ways (sim/holder/heat.rs, deliberately tg-divergent).
-- So the bottle a chemist puts down is a bottle that cools, and every
-- kelvin it loses walks the gauge back down the same line: five
-- minutes on the deck and 150 atmospheres has become 8, which is the
-- vapour pressure of liquid chlorine at room temperature and the
-- number the shelf is really offering.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
t.drop(p)
t.tick()
t.run_seconds(300)

local cooled = t.vessel(bottle)
near(cooled.moles, 0.25, 1e-6, "a stopper means nothing left while it cooled")
near(
    cooled.temp_k,
    t.room_temperature(1, 1),
    1.5,
    "the bottle has come back to the deck's own temperature"
)
near(
    cooled.pressure_kpa,
    chlorine_line_kpa(cooled.temp_k),
    5.0,
    "and the gauge came down the line with it"
)
assert(
    cooled.pressure_kpa < 1000.0,
    "about eight atmospheres, not a hundred and fifty: " .. cooled.pressure_kpa
)
assert(
    (cooled.contents.chlorine.liquid or 0) > 0.9 * 0.25,
    "and nine tenths of the press is liquid chlorine on the shelf"
)
