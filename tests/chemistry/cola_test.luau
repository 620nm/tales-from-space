local ui_controls = require("@helpers/ui_controls")
local composition = require("@helpers/composition")

-- Drinking: a swig moves 0.05 mol from the can to the bloodstream, and
-- metabolism burns the sugar whose handler heals oxygen damage. (Port of
-- the observable half of the Rust m7 test.)
--
-- Conservation is here too now. The header used to defer it "until t
-- grows a container query": `t.matter_totals` is one, and it is better
-- than the one that was wanted -- the whole station's matter, the can
-- and the bloodstream and the room counted together, so what a swig
-- moves is asserted by the books not moving at all.
local CANTEEN = [==[(
    name: "canteen floor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    structures: [(2, 1, "player_spawn")],
    items: [(1, 1, "cola")],
)]==]

t.world(CANTEEN, 7)

local p = t.join()
t.tick()

-- A rough shift so far: some oxygen damage to heal.
t.set_health(p, { oxy = 30 })

t.click(p, 1, 1, t.target_at(p, 1, 1, "cola")) -- pick up the can
t.tick()
assert(t.hands(p).held == "cola", "the can is held")
assert(t.blood_moles(p) == 0, "nothing in the blood yet")

-- The books, read one tick before the mouthful and one tick after it.
local books = t.matter_totals()

composition.click_deck(p, 2, 1) -- drink from the held can
t.tick()
local swig = t.blood_moles(p)
assert(math.abs(swig - 0.05) < 1e-9, ("one 0.05 mol gulp, got %g"):format(swig))

-- A SWIG IS HEARD. The gesture plays `sound/drink` off the can's own
-- tile (lib/vessel.luau, the sip branch), which is the only part of
-- drinking a bystander gets, and the part a silent refusal would take
-- away without changing a single mole.
local heard = table.concat(t.sounds(p), "\n")
assert(heard:find("drink", 1, true) ~= nil, "the swig is heard: " .. heard)

-- AND NOT ONE MOLE WAS MADE OR LOST DOING IT. A transfer moves matter
-- between two bodies of it; the station-wide total is indifferent to
-- which body holds it, so the can's two substances are worth exactly
-- what they were worth a tick ago. The window is a clean one -- no
-- chemistry step falls inside it, which is not assumed but asserted:
-- nothing has fermented yet, so nothing has been transmuted yet.
local moved = t.matter_totals()
assert((moved.substances.ethanol or 0) == 0, "no brewing yet, so the window is a bare transfer")
for _, id in ipairs({ "water", "sugar" }) do
    local was, now = books.substances[id] or 0, moved.substances[id] or 0
    assert(
        math.abs(now - was) < 1e-9,
        ("the station's %s is where it was: %g -> %g"):format(id, was, now)
    )
end

-- Metabolism burns the sugar; sugar's mob.life heals oxy.
local sugar = t.blood(p).sugar
assert(sugar ~= nil and sugar > 0, "the swig carried sugar into the blood")

local before = ui_controls.number(t.health(p).oxy)
t.run_ticks(400)
local after = ui_controls.number(t.health(p).oxy)
assert(after < before, ("sugar healed oxy: %g -> %g"):format(before, after))
assert(t.blood_moles(p) < swig, "metabolism removed moles from the blood")

-- THE HANDLER IS HANDED A NUMBER.
--
-- `mob.life(ctx, self, user, moles)` takes four arguments and the
-- fourth is the moles this metabolism trip burned. A handler that names
-- three parameters binds the BODY to `moles`; arithmetic on a handle
-- throws, and a handler that throws loses its whole effect buffer -- so
-- the heal would silently never land at all. Sugar's heal is written
-- as `moles * 125`, which makes the arithmetic itself the proof.
--
-- Every heal is a ledger row, so the trips are readable one by one. A
-- trip that burns a full `metabolism_rate` is worth exactly 0.5 oxy
-- and no trip can be worth more; a trip that burns less pays less,
-- and a FLAT half-point a trip could not produce that second number
-- at all. The swig carries ~0.0083 mol of sugar and does not last
-- four trips, because the bloodstream is 310 K and fermentation is
-- happy there (reactions/fermentation.luau) -- the brewing takes its
-- cut of the same sugar, which is why the trips total less than the
-- swig was worth.
local full = 0.004 * 125.0 -- metabolism_rate x the per-mole heal
local function pool_amount(row: SpecLedgerRow, id: string): number
    for _, value in ipairs(ui_controls.array(row.pools or {})) do
        local entry = ui_controls.array(value)
        if entry[1] == id then
            return ui_controls.number(entry[2])
        end
    end
    return 0
end
local trips: { number } = {}
for _, row in ipairs(t.ledger_rows("Healed")) do
    -- Whose receipt it is. Every one of these rows is the SUBSTANCE's
    -- file deciding, not the body's: a heal the body handed itself
    -- would total the same and mean nothing, and the sum below is read
    -- back as what metabolism burned.
    assert(
        row.actor.kind == "script" and row.actor.file == "substances/sugar.luau",
        "a heal attributed to the sugar that paid for it"
    )
    trips[#trips + 1] = pool_amount(assert(row), "oxy")
end
assert(#trips >= 2, "the swig was burned over several trips: " .. #trips)
local healed = 0
local tapered = false
for _, oxy in ipairs(trips) do
    assert(
        oxy > 0 and oxy <= full + 1e-6,
        ("a trip paid %g, over the %g a full one is worth"):format(oxy, full)
    )
    tapered = tapered or oxy < full - 1e-6
    healed = healed + oxy
end
assert(math.abs(trips[1] - full) < 1e-6, ("a full trip pays %g, got %g"):format(full, trips[1]))
assert(tapered, "and the trip that burned the dregs paid proportionally less")
assert(healed <= sugar * 125.0 + 1e-6, "no trip healed sugar it had not burned")
assert(#t.ledger_rows("ScriptError") == 0, "and no metabolism handler threw")

-- ...AND THE BOOKS OVER THE METABOLISM, WHICH DO NOT BALANCE, HONESTLY.
--
-- Sugar is the one thing in here that is SPENT rather than moved, and
-- it has exactly two doors out. Metabolism BURNS it (substances/sugar.
-- luau, `metabolism_rate`) and fermentation TRANSMUTES it (reactions/
-- fermentation.luau, one sugar to two ethanol), and both doors keep a
-- receipt: the heal rows above say what the first took, at 125 oxy a
-- mole, and the ethanol standing on the station says what the second
-- took. So the sugar the books are missing is accounted for, and the
-- prose at the top of this block -- "the brewing takes its cut of the
-- same sugar, which is why the trips total less than the swig was
-- worth" -- is an assertion rather than a claim.
local ended = t.matter_totals()
local spent = (books.substances.sugar or 0) - (ended.substances.sugar or 0)
local burned = healed / 125.0
local brewed = (ended.substances.ethanol or 0) / 2.0
assert(spent > 0, "the sugar is being spent: " .. spent)
assert(brewed > 0, "and some of it is going to the brewing: " .. brewed)
assert(
    spent >= burned + brewed - 1e-9,
    ("%g of sugar spent, against %g burned and %g brewed"):format(spent, burned, brewed)
)
assert(
    spent > burned + 1e-9,
    ("which is why the trips are worth less than the swig: %g vs %g"):format(spent, burned)
)

-- ---------------------------------------------------------------
-- AND AGAIN, SIX TIMES, WITH THE BODY WORKING BETWEEN EVERY ONE.
--
-- One swig proves the gesture. A shift is a lot of swigs, and the
-- failures a second one can have that a first cannot are the ones worth
-- a loop: a handler that keeps something between calls and throws on
-- the call after, and a host that answers a repeated thrower by
-- QUARANTINING the file -- which takes the drink away silently, for the
-- rest of the shift, without any single swig ever looking wrong.
--
-- A fresh canteen: the can above has been drunk from and left to brew
-- for four hundred ticks, and six more mouthfuls is most of what it
-- shipped with.
-- ---------------------------------------------------------------
t.world(CANTEEN, 7)

local probe = t.join()
t.tick()
t.set_health(probe, { oxy = 30 })
t.click(probe, 1, 1, t.target_at(probe, 1, 1, "cola"))
t.tick()
assert(t.hands(probe).held == "cola", "a fresh can, in hand")

local worked = 0
for round = 1, 6 do
    composition.click_deck(probe, 2, 1)
    -- A metabolism trip is every 40 ticks (sim/life.rs), so 45 buys at
    -- least one between this swig and the next.
    t.run_ticks(45)

    -- The POSITIVE CONTROL for the two negatives under it, and the
    -- reason they are asked in this order: `t.ledger_rows` answers a
    -- name it does not know with an empty list, so a spec that only
    -- ever asks for rows it expects none of has proved nothing at all.
    -- This asks in the same spelling for a row that must be there, and
    -- counts it.
    local drank = #t.ledger_rows("Drank")
    assert(drank == round, ("round %d: %d swigs on the record"):format(round, drank))
    local trip_rows = #t.ledger_rows("Healed")
    assert(trip_rows > worked, ("round %d: the body worked before the next swig"):format(round))
    worked = trip_rows

    assert(
        #t.ledger_rows("ScriptError") == 0,
        ("round %d: a handler threw and lost its effects"):format(round)
    )
    assert(
        #t.ledger_rows("ScriptQuarantined") == 0,
        ("round %d: a handler was shut off for the rest of the shift"):format(round)
    )
end
