local ui_controls = require("@helpers/ui_controls")

-- A window has a CEILING as well as a floor, and that is the reason the
-- reaction chamber has a dial rather than a switch.
--
-- Ash is the rule with both ends on this shelf: tg's `required_temp` of
-- 480 through the documented bell mapping is 480 / 500 / 900 / 920
-- (reactions/ash.luau), so a chamber dialled to 400 does nothing at
-- all, one dialled to 700 runs it dry, and one dialled past 920 stops
-- again. Three answers from one knob, and the third is the one a
-- chemist never guesses.
--
-- THE SECOND REFUSAL IS HARD TO STAGE, and the staging is the
-- interesting part. A heater ramps, so a beaker of naphtha cannot get from
-- room temperature to 960 K without crossing the window on the way up
-- and turning into ash in the middle of it. The second beaker
-- therefore gets naphtha pressed in while the vessel is already too hot:
-- it is made ABOVE the ash window's ceiling and stays naphtha, which is
-- a thing a chemist can actually do,
-- and the only honest way to ask "what happens at 960 K" of a rule that
-- would otherwise have fired at 500.
--
-- This spec used to stage the same three answers on nitrous oxide,
-- whose recipe wanted a mole of nitrogen and two of oxygen. Those are
-- permanent gases: a source deposits them as gas, and a gas pressed
-- over an open beaker is refused rather than obeyed (D19). They come
-- back to chemistry from a canister into a sealed vessel, and the N2O
-- recipe is written around that share.
local PRESS = 0.75
-- A twentieth of a press of naphtha, and the amount is GEOMETRY talking
-- (docs/CHEMISTRY.md 5, D16). Naphtha is 112.22 g/mol at 0.75 g/mL, so
-- a small press fits comfortably in a 50 mL beaker and the ash
-- conversion is not geometry-limited.
local LEG = 0.05
-- ...and that naphtha is what the ash window is then asked about.
local MADE = LEG

local function near(a: number, b: number, slack: number, what: string)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key: string)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

t.world(
    [==[(
    name: "chem bench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Apc)),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o.a#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn")],
    items: [(1, 2, "beaker"), (3, 2, "beaker")],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local dispenser = t.target_at(p, 1, 1)
local heater = t.target_at(p, 3, 1)
local cold = assert(t.target_at(p, 1, 2, "beaker"))
local hot = assert(t.target_at(p, 3, 2, "beaker"))

local function take(handle, x, y)
    t.click(p, x, y, handle)
    t.tick()
end

local function dock(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
    assert(t.hands(p).held == nil, "the vessel went into the machine")
end

local function panel(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

local function press(key)
    ui_controls.toggle(p, "dispense", key)
    t.run_ticks(2)
end

-- Turn the dial before a press: capacity is geometry now
-- (docs/MATTER.md 5), so a 50 mL beaker takes far more of these than
-- the recipe wants, and the amount that goes in is the chemist's to
-- choose rather than the glass's to impose.
local function dial_to(moles)
    ui_controls.set(p, "amount", moles)
    t.run_ticks(2)
end

local function eject()
    ui_controls.toggle(p, "eject")
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "the vessel comes back out")
end

local function dial(kelvin)
    ui_controls.set(p, "temperature", kelvin)
    t.run_ticks(2)
end

-- Naphtha is the shared fuel and petrochemical feedstock. It is a
-- dispenser liquid, so a basic lab can make the ash precursor without
-- a separate refinery or a gas supply.
local function brew_naphtha(beaker)
    dock(dispenser, 1, 1)
    panel(dispenser, 1, 1)
    dial_to(LEG)
    press("naphtha")
    dial_to(PRESS)
    t.run_seconds(30)
    near(amount(beaker, "naphtha"), MADE, 1e-6, "a press of naphtha landed")
end

-- ---------------------------------------------------------------
-- ONE: BELOW THE WINDOW, NOTHING.
-- ---------------------------------------------------------------
take(cold, 1, 2)
brew_naphtha(cold)

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(400)
ui_controls.toggle(p, "power")
t.run_seconds(120)
near(assert(t.holder_k(cold)), 400.0, 1.0, "the chamber holds it at 400 K")
near(amount(cold, "ash"), 0.0, 1e-12, "eighty kelvin short is short")
near(amount(cold, "naphtha"), MADE, 1e-6, "and every mole of naphtha is still naphtha")

-- ---------------------------------------------------------------
-- TWO: INSIDE IT, IT GOES.
--
-- Three hundred kelvin up the dial and the same beaker runs dry: one
-- of ash for one naphtha, and the ash is a
-- POWDER standing in the glass rather than a second liquid.
-- ---------------------------------------------------------------
dial(700)
t.run_seconds(120)
near(assert(t.holder_k(cold)), 700.0, 25.0, "the chamber took it up into the window")
near(amount(cold, "ash"), MADE, 1e-6, "every mole of naphtha became a mole of ash")
near(amount(cold, "naphtha"), 0.0, 1e-6, "and there is none of it left")

ui_controls.toggle(p, "power")
eject()
t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: ABOVE IT, NOTHING AGAIN.
--
-- The second beaker is brought to 960 K holding a little ballast, and
-- naphtha is pressed in hot. The ballast absorbs the nozzle's 300 K
-- addition so the beaker remains above the ash window's ceiling.
--
-- The iron is there for its 25 J/(mol*K) and nothing else: no rule in
-- this pack's roster names it, so it is heat capacity with no opinions.
-- ---------------------------------------------------------------
-- The dial's smallest step, off machines/chem_dispenser.luau: one tg
-- unit at 1 u = 0.025 mol. A tenth of a leg is under the notch, so
-- this is the smallest press a chemist can actually make.
local NOTCH = 0.025
take(hot, 3, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(PRESS)
press("iron")
press("carbon")
press("iron")
press("carbon")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(960)
ui_controls.toggle(p, "power")
t.run_seconds(150)
assert(
    assert(t.holder_k(hot)) > 940.0,
    "the chamber overshot the window on purpose: " .. tostring(t.holder_k(hot))
)

eject()
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(NOTCH)
press("naphtha")
dial_to(PRESS)
assert(
    assert(t.holder_k(hot)) > 920.0,
    "and the mixture is still over the window: " .. tostring(t.holder_k(hot))
)

-- Five minutes, because the ash rule is running at a QUARTER of its
-- plateau up here and a rate that reads
-- concentration is a decay besides (docs/CHEMISTRY.md 5).
t.run_seconds(320)
local made = amount(hot, "naphtha")
assert(made > 0.0, "the naphtha stayed above the ash window: " .. made .. " mol")
near(amount(hot, "ash"), 0.0, 1e-12, "over the window is as shut as under it")

-- ...and the proof that it was the TEMPERATURE and not the mixture:
-- put the same beaker back on the dial at 700 and every mole of naphtha
-- standing in it converts, coming down into the window from above.
-- Four minutes rather than two and a half: the naphtha here is a couple of
-- notches in a beaker of ballast rather than a neat batch, and a decay
-- in a dilute solution has the longer tail.
eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(700)
t.run_seconds(240)
near(amount(hot, "ash"), made, 1e-3, "coming down into the window works as well as up")
near(amount(hot, "naphtha"), 0.0, 1e-3, "and it spends the naphtha it would not touch at 960")
