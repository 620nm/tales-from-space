-- Blood packs are two-liter sealed vessels, with their blood type carried
-- by the vessel rather than inferred from the item name.
local MAP = [==[(
    name: "blood pack bench",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "##############", "#............#", "#............#", "##############" ],
            structures: [(4, 1, "player_spawn")],
            items: [
                (4, 1, "blood_pack"),
                (1, 1, "blood_pack.o_minus"),
                (2, 1, "blood_pack.o_plus"),
                (3, 1, "blood_pack.a_minus"),
                (5, 1, "blood_pack.a_plus"),
                (6, 1, "blood_pack.b_minus"),
                (7, 1, "blood_pack.b_plus"),
                (8, 1, "blood_pack.ab_minus"),
                (9, 1, "blood_pack.ab_plus"),
                (10, 1, "blood_pack.random"),
                (11, 1, "syringe"),
                (12, 1, "beaker.water"),
                (4, 2, "beaker"),
                (5, 2, "water_bottle"),
            ],
        ),
    ],
)]==]

local GESTURE_MAP = [==[(
    name: "blood pack gesture bench",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "########", "#......#", "#......#", "#......#", "########" ],
            structures: [(3, 2, "player_spawn")],
            items: [
                (3, 1, "blood_pack"),
                (2, 2, "blood_pack.a_plus"),
                (4, 2, "syringe"),
                (2, 1, "beaker.water"),
                (4, 1, "beaker"),
                (3, 3, "water_bottle"),
                (4, 3, "water_bottle.empty"),
            ],
        ),
    ],
)]==]

type VesselRead = { contents: { [string]: number }, blood_type: number? }

local function start_round(map: string): number
    t.world(map, 0)
    local player = t.join()
    t.run_seconds(1)
    t.tick()
    return player
end

local function contents(target: SpecObservedTarget): { [string]: number }
    return assert(t.contents(target), "the observed item reads as a vessel")
end

local function blood_type(target: SpecObservedTarget): number?
    for _, rider in ipairs(t.riders(target) or {}) do
        if rider.id == "blood_identity" and typeof(rider.fields.type) == "number" then
            return rider.fields.type
        end
    end
    return nil
end

local function read_vessel(target: SpecObservedTarget): VesselRead
    local copied: { [string]: number } = {}
    for id, moles in pairs(contents(target)) do
        copied[id] = moles
    end
    return { contents = copied, blood_type = blood_type(target) }
end

local function total(reading: VesselRead): number
    local sum = 0
    for _, moles in pairs(reading.contents) do
        sum += moles
    end
    return sum
end

local function unchanged(target: SpecObservedTarget, before: VesselRead, label: string)
    local after = read_vessel(target)
    for id, moles in pairs(before.contents) do
        assert(math.abs((after.contents[id] or 0) - moles) < 1e-12, label .. " keeps " .. id)
    end
    for id, moles in pairs(after.contents) do
        assert(math.abs((before.contents[id] or 0) - moles) < 1e-12, label .. " adds no " .. id)
    end
    assert(after.blood_type == before.blood_type, label .. " keeps its blood identity")
end

local function unchanged_blood_identity(target: SpecObservedTarget, before: VesselRead, label: string)
    assert(blood_type(target) == before.blood_type, label .. " keeps its blood identity")
end

local function ledger_mark(): number
    local maximum = 0
    for _, row in ipairs(t.ledger_rows()) do
        if row.seq > maximum then
            maximum = row.seq
        end
    end
    return maximum
end

local function no_new_poured(mark: number, label: string)
    for _, row in ipairs(t.ledger_rows("Poured")) do
        assert(row.seq <= mark, label .. " records no new Poured row")
    end
end

local function assert_one_pour_since(
    mark: number,
    player: number,
    expected_from: string,
    expected_to: string,
    expected_file: string,
    label: string
)
    local rows: {SpecLedgerRow} = {}
    for _, row in ipairs(t.ledger_rows()) do
        if row.seq > mark then
            table.insert(rows, row)
        end
    end

    local pour_count = 0
    local played_count = 0
    local poured: SpecLedgerRow? = nil
    local played: SpecLedgerRow? = nil
    for _, row in ipairs(rows) do
        if row.event == "poured" then
            pour_count += 1
            poured = row
        elseif row.event == "played" then
            played_count += 1
            played = row
        end
    end
    assert(pour_count == 1, label .. " records exactly one Poured row")
    assert(played_count == 1, label .. " records exactly one Played row")

    local played_row = assert(played, label .. " has its player gesture")
    local player_body = t.body_id(player)
    local played_actor = played_row.actor
    assert(
        played_actor.kind == "player" and played_actor.id == player_body,
        label .. " belongs to this player's body"
    )
    assert(
        typeof(played_row.session) == "number" and played_row.session == player,
        label .. " belongs to this player session"
    )
    assert(
        typeof(played_row.claim) == "string" and played_row.claim == "interact",
        label .. " records the actual click claim"
    )

    local poured_row = assert(poured, label .. " has its native pour")
    assert(poured_row.event == "poured", label .. " records the Poured event")
    assert(
        typeof(poured_row.from) == "string" and poured_row.from == expected_from,
        label .. " names the actual source"
    )
    assert(
        typeof(poured_row.to) == "string" and poured_row.to == expected_to,
        label .. " names the actual receiver"
    )
    assert(
        typeof(poured_row.moles) == "number" and poured_row.moles > 0,
        label .. " records a positive quantity"
    )
    local pour_actor = poured_row.actor
    assert(
        pour_actor.kind == "script"
            and pour_actor.file == expected_file
            and pour_actor.triggered_by == player_body,
        label .. " names the source handler and its player body"
    )

    local cause_seq = assert(poured_row.cause, label .. " retains its causal row")
    local cause: SpecLedgerRow? = nil
    for _, row in ipairs(rows) do
        if row.seq == cause_seq then
            cause = row
        end
    end
    local cause_row = assert(cause, label .. " links to a recorded cause")
    assert(
        cause_row.event == "script_provenance" and cause_row.cause == played_row.seq,
        label .. " links script provenance to the same click"
    )
    local cause_actor = cause_row.actor
    assert(
        cause_actor.kind == "script"
            and cause_actor.file == expected_file
            and cause_actor.triggered_by == player_body,
        label .. " attributes script provenance to the source handler and player body"
    )
end

local function no_script_errors(label: string)
    local errors = t.script_errors()
    if #errors == 0 then
        return
    end
    local details = {}
    for _, failure in ipairs(errors) do
        table.insert(details, failure.file .. ": " .. failure.why)
    end
    error(label .. " script errors: " .. table.concat(details, " | "))
end

local function assert_no_bag_gestures(player: number)
    local held_site: SpecItemSite = { Held = { hand = t.hands(player).active - 1 } }
    local target: SpecActionTarget = { Inventory = held_site }
    for _, action in ipairs(t.action_hints(player, target)) do
        assert(
            action.id ~= "pour" and action.id ~= "drink" and action.id ~= "spill",
            "blood packs expose no " .. action.id .. " action"
        )
    end
end

local function exact_overlay(target: SpecObservedTarget)
    local overlays = t.overlays(target)
    assert(#overlays == 1 and overlays[1] == "bloodpack100", "full bags wear exactly bloodpack100")
end

local function random_type(player: number): number
    local random = assert(t.target_at(player, 10, 1, "blood_pack.random"))
    local kind = blood_type(random)
    assert(kind ~= nil and kind >= 0 and kind <= 7, "the random bag carries one of the eight types")
    assert(math.abs((contents(random).blood or 0) - 5.0) < 1e-12, "the random bag holds five moles")
    exact_overlay(random)
    local look = assert(t.examine(player, 10, 1, random))
    assert(look.title == "blood pack", "the random bag keeps the generic title")
    assert(look.sprite == "bloodpack", "the random bag uses the blood-pack sprite")
    return kind
end

-- Every dotted form is player-placeable, filled, typed, and named. The
-- random form is checked by observed results across identical seeded rounds.
local p = start_round(MAP)
local base = assert(t.target_at(p, 4, 1, "blood_pack"))
local base_reading = assert(t.vessel(base))
assert(math.abs(base_reading.volume_l - 2.0) < 1e-12, "the base blood pack is two liters")
assert(base_reading.sealed, "the base blood pack starts sealed")
assert(total(read_vessel(base)) == 0, "the base blood pack starts empty")
assert(blood_type(base) == nil, "the base blood pack starts untyped")
assert(#t.overlays(base) == 0, "the empty base blood pack has no overlay")

local typed = {
    { id = "blood_pack.o_minus", x = 1, kind = 0, title = "blood pack - O-" },
    { id = "blood_pack.o_plus", x = 2, kind = 1, title = "blood pack - O+" },
    { id = "blood_pack.a_minus", x = 3, kind = 2, title = "blood pack - A-" },
    { id = "blood_pack.a_plus", x = 5, kind = 3, title = "blood pack - A+" },
    { id = "blood_pack.b_minus", x = 6, kind = 4, title = "blood pack - B-" },
    { id = "blood_pack.b_plus", x = 7, kind = 5, title = "blood pack - B+" },
    { id = "blood_pack.ab_minus", x = 8, kind = 6, title = "blood pack - AB-" },
    { id = "blood_pack.ab_plus", x = 9, kind = 7, title = "blood pack - AB+" },
}
for _, expected in ipairs(typed) do
    local bag = assert(t.target_at(p, expected.x, 1, expected.id))
    assert(math.abs((contents(bag).blood or 0) - 5.0) < 1e-12, expected.id .. " holds five moles of blood")
    assert(blood_type(bag) == expected.kind, expected.id .. " carries its roster index")
    exact_overlay(bag)
    local look = assert(t.examine(p, expected.x, 1, bag))
    assert(look.title == expected.title, expected.id .. " has its blood-type name")
end
local first_random_type = random_type(p)

-- Read the action surface from a held empty and full pack.
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "blood_pack")))
t.tick()
assert(t.hands(p).held == "blood_pack", "the empty base pack can be held")
assert_no_bag_gestures(p)
t.drop(p)
t.tick()
local observed_full_a_plus_bag = assert(t.target_at(p, 5, 1, "blood_pack.a_plus"))
t.click(p, 5, 1, observed_full_a_plus_bag)
t.tick()
assert(t.hands(p).held == "blood_pack.a_plus", "the full A+ pack can be held")
assert_no_bag_gestures(p)
local full_before_self_use = read_vessel(observed_full_a_plus_bag)
t.use_self(p)
t.run_seconds(1)
t.tick()
unchanged(observed_full_a_plus_bag, full_before_self_use, "the full bag after self-use")
assert(t.hands(p).held == "blood_pack.a_plus", "self-use leaves the full blood pack held")
t.drop(p)
t.tick()
no_script_errors("blood-pack contracts")

local repeated = start_round(MAP)
assert(random_type(repeated) == first_random_type, "recreating the same seeded fixture reproduces its observed random type")
no_script_errors("blood-pack seeded repeat")

-- Real syringe and vessel gestures have working positive controls before
-- each attempted bag interaction, so refusals cannot pass on a dead route.
p = start_round(GESTURE_MAP)
local syringe = assert(t.target_at(p, 4, 2, "syringe"))
local water = assert(t.target_at(p, 2, 1, "beaker.water"))
local empty_beaker = assert(t.target_at(p, 4, 1, "beaker"))
local empty_pack = assert(t.target_at(p, 3, 1, "blood_pack"))
local full_pack = assert(t.target_at(p, 2, 2, "blood_pack.a_plus"))
local bottle = assert(t.target_at(p, 3, 3, "water_bottle"))

t.click(p, 4, 2, syringe)
t.tick()
assert(t.hands(p).held == "syringe", "the actual syringe is held")
local water_before_draw = read_vessel(water)
local syringe_before_draw = read_vessel(syringe)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "beaker.water")))
t.run_seconds(2)
t.tick()
assert(total(read_vessel(syringe)) > total(syringe_before_draw), "the syringe draws from ordinary beaker water")
assert(total(read_vessel(water)) < total(water_before_draw), "the positive draw empties its actual source")

local full_before_draw = read_vessel(full_pack)
local syringe_before_bag_draw = read_vessel(syringe)
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "blood_pack.a_plus")))
t.run_seconds(2)
t.tick()
unchanged(full_pack, full_before_draw, "the full A+ bag after syringe draw refusal")
unchanged(syringe, syringe_before_bag_draw, "the syringe after bag draw refusal")

t.use_self(p)
t.run_seconds(1)
t.tick()
local receiver_before_inject = read_vessel(empty_beaker)
local syringe_before_inject = read_vessel(syringe)
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "beaker")))
t.run_seconds(2)
t.tick()
assert(total(read_vessel(empty_beaker)) > total(receiver_before_inject), "the loaded syringe injects into an ordinary beaker")
assert(total(read_vessel(syringe)) < total(syringe_before_inject), "the positive injection uses syringe contents")

t.use_self(p)
t.tick()
local syringe_before_refill = read_vessel(syringe)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "beaker.water")))
t.run_seconds(2)
t.tick()
assert(total(read_vessel(syringe)) > total(syringe_before_refill), "the syringe reloads before testing injection refusal")
t.use_self(p)
t.tick()

local empty_before_inject = read_vessel(empty_pack)
local syringe_before_bag_inject = read_vessel(syringe)
assert(total(syringe_before_bag_inject) > 0, "the refused injection has blood-capable contents in its syringe")
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "blood_pack")))
t.run_seconds(2)
t.tick()
unchanged(empty_pack, empty_before_inject, "the empty bag after syringe injection refusal")
unchanged(syringe, syringe_before_bag_inject, "the syringe after bag injection refusal")

-- A beaker pour and a non-beaker bottle pour both work on ordinary glass,
-- then leave blood packs and their riders untouched.
t.drop(p)
t.run_seconds(1)
t.tick()
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "beaker.water")))
t.tick()
local water_before_pour = read_vessel(water)
local beaker_before_pour = read_vessel(empty_beaker)
local beaker_pour_mark = ledger_mark()
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "beaker")))
t.run_seconds(2)
t.tick()
assert(total(read_vessel(water)) < total(water_before_pour), "beaker.water pours into ordinary glass")
assert(total(read_vessel(empty_beaker)) > total(beaker_before_pour), "the ordinary-glass pour has a receiver")
assert_one_pour_since(
    beaker_pour_mark,
    p,
    "beaker (water)",
    "beaker",
    "items/vessels/beaker.luau",
    "beaker.water ordinary-glass pour"
)

local empty_before_pour = read_vessel(empty_pack)
local beaker_before_bag_pour = read_vessel(water)
local beaker_bag_refusal_mark = ledger_mark()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "blood_pack")))
t.run_seconds(2)
t.tick()
unchanged(empty_pack, empty_before_pour, "the empty bag after beaker pour refusal")
no_new_poured(beaker_bag_refusal_mark, "beaker.water after bag pour refusal")
unchanged_blood_identity(water, beaker_before_bag_pour, "beaker.water after bag pour refusal")

t.drop(p)
t.run_seconds(1)
t.tick()
t.click(p, 3, 3, assert(t.target_at(p, 3, 3, "water_bottle")))
t.tick()
assert(t.hands(p).held == "water_bottle", "the non-beaker water bottle is held")
t.use_self(p)
t.run_seconds(1)
t.tick()
assert(not assert(t.vessel(bottle)).sealed, "the bottle is opened through its real self-use")
local bottle_before_pour = read_vessel(bottle)
local beaker_before_bottle = read_vessel(empty_beaker)
local bottle_pour_mark = ledger_mark()
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "beaker")))
t.run_seconds(2)
t.tick()
assert(total(read_vessel(bottle)) < total(bottle_before_pour), "the opened bottle pours into ordinary glass")
assert(total(read_vessel(empty_beaker)) > total(beaker_before_bottle), "the bottle pour has a working receiver")
assert_one_pour_since(
    bottle_pour_mark,
    p,
    "bottle of water",
    "beaker",
    "items/vessels/water_bottle.luau",
    "non-beaker bottle ordinary-glass pour"
)

local empty_before_bottle = read_vessel(empty_pack)
local bottle_before_bag = read_vessel(bottle)
local bottle_bag_refusal_mark = ledger_mark()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "blood_pack")))
t.run_seconds(2)
t.tick()
unchanged(empty_pack, empty_before_bottle, "the empty bag after non-beaker bottle pour refusal")
no_new_poured(bottle_bag_refusal_mark, "the non-beaker bottle after bag pour refusal")
unchanged_blood_identity(bottle, bottle_before_bag, "the non-beaker bottle after bag pour refusal")
local full_before_bottle = read_vessel(full_pack)
local bottle_before_full_bag = read_vessel(bottle)
local full_bag_bottle_refusal_mark = ledger_mark()
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "blood_pack.a_plus")))
t.run_seconds(2)
t.tick()
unchanged(full_pack, full_before_bottle, "the full A+ bag after non-beaker bottle use")
no_new_poured(full_bag_bottle_refusal_mark, "the bottle after full-bag use")
unchanged_blood_identity(bottle, bottle_before_full_bag, "the bottle after full-bag use")
assert(t.hands(p).held == "water_bottle", "the refused full-bag gesture leaves the bottle in hand")

local empty_bottle = assert(t.target_at(p, 4, 3, "water_bottle.empty"))
assert(total(read_vessel(empty_bottle)) == 0, "the authored empty bottle has no contents")
assert(t.vessel(empty_bottle) ~= nil, "the empty bottle still has a vessel holder")
t.drop(p)
t.tick()
t.click(p, 4, 3, assert(t.target_at(p, 4, 3, "water_bottle.empty")))
t.tick()
assert(t.hands(p).held == "water_bottle.empty", "the authored empty non-beaker bottle is held")
local empty_bottle_before = read_vessel(empty_bottle)
local typed_before_empty_bottle = read_vessel(full_pack)
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "blood_pack.a_plus")))
t.run_seconds(2)
t.tick()
unchanged(full_pack, typed_before_empty_bottle, "the typed bag after empty-bottle use")
unchanged(empty_bottle, empty_bottle_before, "the empty non-beaker bottle after bag use")
no_script_errors("blood-pack syringe and pour gestures")

-- Pin both offhand orientations. A working syringe-to-beaker inventory
-- gesture precedes the two blood-pack refusals.
p = start_round(GESTURE_MAP)
syringe = assert(t.target_at(p, 4, 2, "syringe"))
water = assert(t.target_at(p, 2, 1, "beaker.water"))
empty_beaker = assert(t.target_at(p, 4, 1, "beaker"))
full_pack = assert(t.target_at(p, 2, 2, "blood_pack.a_plus"))
t.click(p, 4, 2, syringe)
t.tick()
assert(t.hands(p).held == "syringe", "the offhand fixture starts with its syringe active")
local syringe_hand = t.hands(p).active - 1
for _ = 1, 2 do
    t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "beaker.water")))
    t.run_seconds(2)
    t.tick()
end
t.use_self(p)
t.tick()
t.swap_hands(p)
t.tick()
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "beaker")))
t.tick()
t.swap_hands(p)
t.tick()
local offhand_syringe_before = read_vessel(syringe)
local offhand_beaker_before = read_vessel(empty_beaker)
t.use_on_other(p)
t.run_seconds(2)
t.tick()
assert(total(read_vessel(syringe)) < total(offhand_syringe_before), "the offhand syringe injects through its real pair route")
assert(total(read_vessel(empty_beaker)) > total(offhand_beaker_before), "the offhand positive control fills its receiver")

t.use_self(p)
t.tick()
local offhand_syringe_before_reload = read_vessel(syringe)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "beaker.water")))
t.run_seconds(2)
t.tick()
assert(total(read_vessel(syringe)) > total(offhand_syringe_before_reload), "the syringe reloads before offhand refusals")
t.use_self(p)
t.tick()

t.swap_hands(p)
t.tick()
t.drop(p)
t.tick()
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "blood_pack.a_plus")))
t.tick()
assert(t.hands(p).held == "blood_pack.a_plus", "the full blood pack occupies the active hand")
local bag_hand = t.hands(p).active - 1
local offhand_full_before = read_vessel(full_pack)
local offhand_syringe_empty = read_vessel(syringe)
t.swap_hands(p)
t.tick()
assert(
    t.hands(p).held == "syringe" and t.hands(p)[bag_hand + 1] == "blood_pack.a_plus",
    "the syringe is active while the full bag is in the other hand"
)
t.use_on_other(p)
t.run_seconds(2)
t.tick()
unchanged(full_pack, offhand_full_before, "the full bag in the other hand")
unchanged(syringe, offhand_syringe_empty, "the active syringe after bag use")

t.swap_hands(p)
t.tick()
assert(
    t.hands(p).held == "blood_pack.a_plus" and t.hands(p)[syringe_hand + 1] == "syringe",
    "the full bag is active while the syringe is in the other hand"
)
local reverse_full_before = read_vessel(full_pack)
local reverse_syringe_before = read_vessel(syringe)
t.use_on_other(p)
t.run_seconds(2)
t.tick()
unchanged(full_pack, reverse_full_before, "the active full bag")
unchanged(syringe, reverse_syringe_before, "the syringe in the other hand")
no_script_errors("blood-pack offhand gestures")

-- The analyzer's positive and empty scans use the normal held-tool route;
-- its private rendered reports identify both typed and untyped vessels.
local SCANNER_MAP = [==[(
    name: "blood pack scanner bench",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "########", "#......#", "########" ],
            structures: [(4, 1, "player_spawn")],
            items: [
                (3, 1, "blood_pack"),
                (5, 1, "blood_pack.a_plus"),
                (4, 1, "health_analyzer"),
            ],
        ),
    ],
)]==]

local scanner = start_round(SCANNER_MAP)
local analyzer = assert(t.target_at(scanner, 4, 1, "health_analyzer"))
local untyped = assert(t.target_at(scanner, 3, 1, "blood_pack"))
local typed_bag = assert(t.target_at(scanner, 5, 1, "blood_pack.a_plus"))
local untyped_before_scan = read_vessel(untyped)
local typed_before_scan = read_vessel(typed_bag)
t.click(scanner, 4, 1, analyzer)
t.tick()
assert(t.hands(scanner).held == "health_analyzer", "the health analyzer is held")

local scanner_messages: {string} = {}

local function capture_messages(): ()
    for _, message in ipairs(t.messages(scanner)) do
        scanner_messages[#scanner_messages + 1] = message
    end
end

local function message_count(expected: string): number
    local found = 0
    for _, message in ipairs(scanner_messages) do
        if message == expected then
            found += 1
        end
    end
    return found
end

local function scan(target: SpecObservedTarget, x: number, id: string, header: string, line: string)
    capture_messages()
    local old_header = message_count(header)
    local old_line = message_count(line)
    t.click(scanner, x, 1, assert(t.target_at(scanner, x, 1, id)))
    t.run_seconds(1)
    t.tick()
    capture_messages()
    assert(message_count(header) == old_header + 1, "the scan publishes its private report header")
    assert(message_count(line) == old_line + 1, "the scan publishes its private blood-volume line")
    assert(t.same_target(target, assert(t.target_at(scanner, x, 1, id))), "the report is for the observed bag")
end

scan(
    typed_bag,
    5,
    "blood_pack.a_plus",
    "Analyzing results for blood pack - A+:",
    "Blood volume: 200 cl, type A+."
)
scan(
    untyped,
    3,
    "blood_pack",
    "Analyzing results for blood pack:",
    "Blood volume: 0 cl, type untyped."
)
unchanged(typed_bag, typed_before_scan, "the analyzer preserves the typed bag")
unchanged(untyped, untyped_before_scan, "the analyzer preserves the empty bag")
no_script_errors("blood-pack analyzer reports")
