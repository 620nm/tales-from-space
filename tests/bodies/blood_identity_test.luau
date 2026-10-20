local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

-- BLOOD IDENTITY, legs 1-4: typed blood, transfused by needle
-- (`content/lib/blood_identity.luau`, docs/TODO.md "Blood identity
-- rider").
--
-- One ward, three crew, a syringe and three beakers: the donor is O-,
-- the receiver is A+, and the medic operates. Seed 3 deals exactly
-- that trio off tg's weights, and the precondition pins all three
-- types, so an engine that rerolls its draws fails here loudly rather
-- than halfway through a leg.
--
-- The bodies hold row 1 and the glass row 2, so the medic's whole
-- round is the (2,1)-(2,2) stair plus the empty row 2: nobody ever
-- steps onto an occupied tile.
--
--   1. Compatible O- into A+ settles silently after one meet: the
--      receiver stays A+, no toxin, one settle write.
--   2. Incompatible A+ into O- is refused with tg's toxin at half the
--      transfused volume (blood.dm:406-410): the receiver stays O-,
--      the donor blood is expelled, the toxin stays and charges.
--   3. A split draw keeps the rider on both halves: two draws off the
--      donor into two beakers, no meetings, both typed O-.
--   4. Blood drawn back out of blood+water clears `blood_identity` as
--      carrier-gone: the emptied mix is riderless, the receiving
--      beaker keeps the type, nothing met.
local SEED = 3
-- Roster indices (content/rosters/blood_types.luau, tg's weights order).
local O_MINUS, A_PLUS = 0, 3
local NORMAL = 13.75 -- 560 u x 0.025 mol/u, content/items/anatomy/human_chest.luau

t.world(
    [==[(
    name: "transfusion ward",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "######", "#....#", "#....#", "######" ],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (3, 1, "player_spawn", { "jobs": "engineer" }),
            ],
            items: [
                (2, 2, "syringe"),
                (1, 2, "beaker"),
                (3, 2, "beaker_large"),
                (4, 2, "beaker.water"),
            ],
        ),
    ],
)]==],
    SEED
)

local medic = t.join("medic")
local donor = t.join("assistant")
local receiver = t.join("engineer")
t.run_ticks(3)
assert(t.pos(medic) == 2, "the medic holds the middle tile")
assert(t.pos(donor) == 1, "the donor is on the medic's west")
assert(t.pos(receiver) == 3, "the receiver is on the medic's east")

local function said(who: number, needle: string): boolean
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end
local function close(got: number, want: number, what: string)
    assert(math.abs(got - want) < 1e-9, ("%s: wanted %g, got %g"):format(what, want, got))
end
local function near(got: number, want: number, slack: number, what: string)
    assert(math.abs(got - want) < slack, ("%s: wanted %g, got %g"):format(what, want, got))
end
local function blood_of(p: number): number
    return ui_controls.number(assert(t.body(p)).blood)
end
local function body_name(x: number, y: number): string
    local here = assert(t.bodies_at(x, y), "a body stands there")
    assert(#here == 1, "exactly one body stands there")
    return (here[1] :: any).name
end
-- The ledger's `blood_identity` rows for one event, oldest first.
local function kind_rows(event: string): { any }
    local out: { any } = {}
    for _, row in ipairs(t.ledger_rows(event)) do
        local r = row :: any
        if r.rider == "blood_identity" then
            table.insert(out, r)
        end
    end
    return out
end
-- A RiderSet row's `type` field, by field name.
local function set_type(row: any): number?
    if row.fields == nil then
        return nil
    end
    for _, field in ipairs(row.fields) do
        local f = field :: any
        if f.name == "type" and typeof(f.value) == "number" then
            return f.value
        end
    end
    return nil
end
-- A vessel's settled type, by field name; nil when it holds none.
local function rider_type(target: SpecObservedTarget): number?
    local entries = t.riders(target)
    if entries == nil then
        return nil
    end
    for _, entry in ipairs(entries) do
        if entry.id == "blood_identity" then
            local v: any = entry.fields.type
            if typeof(v) == "number" then
                return v
            end
        end
    end
    return nil
end
local function step(dir: "east" | "west" | "south" | "north")
    t.move(medic, dir)
    t.run_ticks(3)
end
local function at(x: number, y: number): boolean
    local mx, my = t.pos(medic)
    return mx == x and my == y
end
local function go(x: number, y: number)
    local mx, my = t.pos(medic)
    while mx < x do
        step("east")
        mx += 1
    end
    while mx > x do
        step("west")
        mx -= 1
    end
    while my < y do
        step("south")
        my += 1
    end
    while my > y do
        step("north")
        my -= 1
    end
    assert(at(x, y), ("the medic reaches %d,%d"):format(x, y))
end
local function take(id: string, x: number, y: number)
    go(x, y)
    if t.hands(medic).held ~= nil then
        t.drop(medic)
        t.tick()
    end
    local target = assert(t.target_at(medic, x, y, id), "the " .. id .. " is there")
    t.click(medic, x, y, target)
    t.run_ticks(2)
end
local function pour_into(id: string, x: number, y: number)
    go(x, y)
    local target = assert(t.target_at(medic, x, y, id), "the " .. id .. " is there")
    t.click(medic, x, y, target)
    t.run_ticks(2)
end
-- The syringe dial, tracked the way delivery_test does: it ships on
-- DRAW, each press turns it round, and the sentence says which way.
local dial = "draw"
local function flip()
    t.use_self(medic)
    t.run_ticks(2)
    if dial == "draw" then
        assert(said(medic, "set the syringe to inject"), "turned round to inject")
        dial = "inject"
    else
        assert(said(medic, "set the syringe to draw"), "turned back to draw")
        dial = "draw"
    end
end
-- A needle on someone else is three seconds of standing still, from
-- the tile beside them (delivery_test.luau).
local function draw_from(patient: number)
    assert(dial == "draw", "the barrel is pointed out of the body")
    go(2, 1)
    local x = t.pos(patient)
    t.click(medic, x, 1, t.body_target(medic, patient))
    t.run_ticks(clock.deadline_ticks(3) + 2)
end
local function inject_into(patient: number)
    assert(dial == "inject", "the barrel is pointed into the body")
    go(2, 1)
    local x = t.pos(patient)
    t.click(medic, x, 1, t.body_target(medic, patient))
    t.run_ticks(clock.deadline_ticks(3) + 2)
end
-- The syringe's observed target, captured before the first take and
-- held onto: a syringe in hand is on no tile, but its target keeps
-- reading (delivery_test.luau).
local syringe_target: SpecObservedTarget? = nil
local function held_blood(): number
    local in_barrel = assert(t.contents(assert(syringe_target, "the syringe is targeted")), "the barrel reads")
    return in_barrel.blood or 0
end

-- ---------------------------------------------------------------
-- THE DEAL. Three stamps, one per body, off tg's weights -- and this
-- seed's trio is the pair the legs need plus their operator.
-- ---------------------------------------------------------------
t.run_seconds(3)
local donor_owner, receiver_owner = body_name(1, 1), body_name(3, 1)
local stamps = kind_rows("rider_set")
assert(#stamps == 3, ("three bodies are stamped, got %d"):format(#stamps))
local dealt: { [string]: number } = {}
for _, row in ipairs(stamps) do
    dealt[row.owner] = assert(set_type(row), "a stamp names its type")
end
assert(dealt[donor_owner] == O_MINUS, "the donor drew O-")
assert(dealt[receiver_owner] == A_PLUS, "the receiver drew A+")
assert(dealt[body_name(2, 1)] == A_PLUS, "the medic drew A+")
for _, who in ipairs({ medic, donor, receiver }) do
    near(blood_of(who), NORMAL, 1e-9, "everyone starts at the plan normal")
end
assert(#t.script_errors() == 0, "stamping runs clean")

syringe_target = assert(t.target_at(medic, 2, 2, "syringe"), "the syringe is on the bench")
take("syringe", 2, 2)

-- ---------------------------------------------------------------
-- LEG 1. Compatible O- into A+ settles silently after one meet.
-- ---------------------------------------------------------------
local arrived0, set0, cleared0 =
    #kind_rows("rider_arrived"), #kind_rows("rider_set"), #kind_rows("rider_cleared")
draw_from(donor)
local barrel = held_blood()
assert(barrel > 0.01, ("the draw fills the barrel, with %g"):format(barrel))
flip()
inject_into(receiver)
local moved = barrel - held_blood()
assert(moved > 0.01, ("the transfusion moved blood, %g"):format(moved))
close(t.blood(receiver).toxin or 0, 0, "compatible blood settles silently: no toxin")
assert(#kind_rows("rider_arrived") - arrived0 == 2, "the draw arrived, then the meet")
assert(#kind_rows("rider_set") - set0 == 1, "the dispatcher settled once")
assert(#kind_rows("rider_cleared") - cleared0 == 1, "the emptied barrel clears")
local function new_meets(owner: string, from: number): number
    local meets = 0
    local rows = kind_rows("rider_arrived")
    for i = from + 1, #rows do
        if rows[i].owner == owner then
            meets += 1
        end
    end
    return meets
end
assert(new_meets(receiver_owner, arrived0) == 1, "exactly one meet, on the receiver")
local settle = kind_rows("rider_set")[set0 + 1]
assert(settle.owner == receiver_owner, "the settle is the receiver's")
assert(set_type(settle) == A_PLUS, "and the receiver stays A+")
assert(#t.script_errors() == 0, "the compatible leg runs clean")

-- ---------------------------------------------------------------
-- LEG 2. Incompatible A+ into O- is refused with tg's toxin at half
-- the transfused volume (blood.dm:406-410).
-- ---------------------------------------------------------------
arrived0, set0, cleared0 = #kind_rows("rider_arrived"), #kind_rows("rider_set"), #kind_rows("rider_cleared")
flip()
draw_from(receiver)
barrel = held_blood()
assert(barrel > 0.01, ("the draw fills the barrel, with %g"):format(barrel))
flip()
inject_into(donor)
moved = barrel - held_blood()
assert(moved > 0.01, ("the transfusion moved blood, %g"):format(moved))
-- Half the volume, to within one metabolism pass: the toxin burns
-- 0.005 a pass from the moment it lands.
near(t.blood(donor).toxin or 0, moved / 2, 0.006, "tg's toxin at half the transfused volume")
assert((t.blood(donor).toxin or 0) > 0, "and the reaction is real")
assert(#kind_rows("rider_arrived") - arrived0 == 2, "the draw arrived, then the meet")
assert(#kind_rows("rider_set") - set0 == 1, "the dispatcher settled once")
assert(new_meets(donor_owner, arrived0) == 1, "exactly one meet, on the donor")
settle = kind_rows("rider_set")[set0 + 1]
assert(settle.owner == donor_owner, "the settle is the donor's")
assert(set_type(settle) == O_MINUS, "and the donor stays O-: refused")
-- Refused means expelled: the harmony pass trims donor blood only, so
-- the blood is back on the line while the toxin is still charging.
t.run_seconds(4)
near(blood_of(donor), NORMAL, 1e-9, "the donor blood is expelled to the normal")
assert((t.blood(donor).toxin or 0) > 0, "the toxin stays beside it")
assert(ui_controls.number(t.health(donor).tox) > 0, "and it charges for its stay")
assert(#t.script_errors() == 0, "the incompatible leg runs clean")

-- ---------------------------------------------------------------
-- LEG 3. A split draw keeps the rider on both halves.
-- ---------------------------------------------------------------
set0 = #kind_rows("rider_set")
flip()
draw_from(donor)
flip()
pour_into("beaker", 1, 2)
flip()
draw_from(donor)
flip()
pour_into("beaker_large", 3, 2)
local half_a = assert(t.target_at(medic, 1, 2, "beaker"), "half A is on the bench")
local half_b = assert(t.target_at(medic, 3, 2, "beaker_large"), "half B is on the bench")
assert(rider_type(half_a) == O_MINUS, "half A keeps the donor's type")
assert(rider_type(half_b) == O_MINUS, "half B keeps the donor's type")
assert(#kind_rows("rider_set") - set0 == 0, "the same rider returning is never a meeting")
assert(#t.script_errors() == 0, "the split leg runs clean")

-- ---------------------------------------------------------------
-- LEG 4. Blood drawn back out of blood+water clears the kind as
-- carrier-gone.
-- ---------------------------------------------------------------
arrived0, set0, cleared0 = #kind_rows("rider_arrived"), #kind_rows("rider_set"), #kind_rows("rider_cleared")
-- Half B becomes the mix: two 10 u water pours beside its blood.
take("beaker.water", 4, 2)
pour_into("beaker_large", 3, 2)
pour_into("beaker_large", 3, 2)
-- And half B is poured back out into half A, the same rider all along.
local mix = assert(t.target_at(medic, 3, 2, "beaker_large"), "the mix beaker is on the bench")
take("beaker_large", 3, 2)
pour_into("beaker", 1, 2)
pour_into("beaker", 1, 2)
pour_into("beaker", 1, 2)
assert(next(assert(t.contents(mix))) == nil, "the mix beaker is empty")
assert(#(t.riders(mix) or {}) == 0, "and riderless")
assert(
    rider_type(assert(t.target_at(medic, 1, 2, "beaker"), "half A is on the bench")) == O_MINUS,
    "the receiving beaker keeps the type"
)
assert(#kind_rows("rider_arrived") - arrived0 == 0, "no arrival is a meeting here")
assert(#kind_rows("rider_set") - set0 == 0, "so the dispatcher never writes")
local cleared = kind_rows("rider_cleared")
assert(#cleared - cleared0 == 1, "one clearing, the emptied mix")
-- The envelope's own `cause` shadows the row's (a row link, not the
-- word), so the word is read off the Debug flatten: one row carries
-- this kind, this owner and `carrier_gone` together, and no earlier
-- clearing shares the owner.
local gone = cleared[cleared0 + 1]
for i = 1, cleared0 do
    assert(cleared[i].owner ~= gone.owner, "no earlier clearing shares the mix beaker")
end
assert(
    t.ledger_has("RiderCleared", "blood_identity", gone.owner, "carrier_gone"),
    "as carrier-gone"
)
assert(#t.script_errors() == 0, "the carrier-gone leg runs clean")
