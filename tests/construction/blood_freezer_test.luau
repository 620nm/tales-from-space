local ui_controls = require("@helpers/ui_controls")
local clock = require("@helpers/clock")

local MAP = [==[ (
    name: "blood freezer stock",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#.......#",
                "#.......#",
                "#.......#",
                "#.......#",
                "#.......#",
                "#.......#",
                "#########",
            ],
            structures: [
                (3, 4, "player_spawn"),
                (4, 4, "freezer.blood"),
                (7, 2, "freezer"),
            ],
        ),
    ],
)]==]

local INITIAL_STOCK: { [string]: number } = {
    blood_pack = 2,
    ["blood_pack.a_minus"] = 1,
    ["blood_pack.b_minus"] = 1,
    ["blood_pack.b_plus"] = 1,
    ["blood_pack.o_minus"] = 1,
    ["blood_pack.o_plus"] = 1,
    ["blood_pack.random"] = 3,
    ["paper.blood_types"] = 1,
}

local TYPED_BLOOD_TYPES: { [string]: number } = {
    ["blood_pack.a_minus"] = 2,
    ["blood_pack.b_minus"] = 4,
    ["blood_pack.b_plus"] = 5,
    ["blood_pack.o_minus"] = 0,
    ["blood_pack.o_plus"] = 1,
}

local STASH_TILES = {
    { x = 2, y = 2 },
    { x = 2, y = 3 },
    { x = 2, y = 4 },
    { x = 2, y = 5 },
    { x = 2, y = 6 },
    { x = 2, y = 7 },
    { x = 3, y = 2 },
    { x = 3, y = 3 },
    { x = 3, y = 5 },
    { x = 3, y = 6 },
    { x = 3, y = 7 },
}

local function start_round(): number
    t.world(MAP, 0)
    local player = t.join()
    t.run_seconds(1)
    t.tick()
    return player
end

local function move_and_settle(player: number, direction: "north" | "south" | "east" | "west"): ()
    t.move(player, direction)
    t.run_ticks(3)
end

local function walk_to(player: number, target_x: number, target_y: number): ()
    local x, y = t.pos(player)
    while x ~= target_x do
        local direction: "east" | "west" = if x < target_x then "east" else "west"
        move_and_settle(player, direction)
        x, y = t.pos(player)
    end
    while y ~= target_y do
        local direction: "north" | "south" = if y < target_y then "south" else "north"
        move_and_settle(player, direction)
        x, y = t.pos(player)
    end
end

local function assert_item_counts(
    actual: { string },
    expected: { [string]: number },
    label: string
): ()
    local counts: { [string]: number } = {}
    for _, id in ipairs(actual) do
        counts[id] = (counts[id] or 0) + 1
    end

    local expected_total = 0
    for id, count in pairs(expected) do
        expected_total += count
        assert((counts[id] or 0) == count, label .. " has " .. id .. " count " .. tostring(count))
        counts[id] = nil
    end
    assert(#actual == expected_total, label .. " has the expected item total")
    for id, count in pairs(counts) do
        assert(count == 0, label .. " has unexpected " .. id)
    end
end

local function blood_type(target: SpecObservedTarget): number?
    for _, rider in ipairs(t.riders(target) or {}) do
        if rider.id == "blood_identity" and typeof(rider.fields.type) == "number" then
            return rider.fields.type
        end
    end
    return nil
end

local function assert_full_pack(target: SpecObservedTarget, expected_type: number, label: string): ()
    local contents = assert(t.contents(target), label .. " exposes its vessel")
    assert(math.abs((contents.blood or 0) - 5.0) < 1e-12, label .. " is full")
    assert(blood_type(target) == expected_type, label .. " carries its expected blood identity")
    local overlays = t.overlays(target)
    assert(#overlays == 1 and overlays[1] == "bloodpack100", label .. " wears the full overlay")
end

local function open_blood_freezer(player: number): SpecObservedTarget
    assert(t.hands(player).held == nil, "opening the freezer uses an empty hand")
    assert(assert(t.structure_at(4, 4)).state == "closed", "the blood freezer starts closed")
    assert(#t.items_at(4, 4) == 0, "the closed blood freezer conceals every stock item")
    local freezer = assert(t.target_at(player, 4, 4, "freezer"))
    t.click(player, 4, 4, freezer)
    t.tick()
    assert(assert(t.structure_at(4, 4)).state == "open", "the blood freezer opens by player action")
    return freezer
end

local function assert_blood_type_paper(player: number): ()
    local window = ui_controls.record(t.ui(player, "writing"))
    local script = ui_controls.record(window.script)
    local data = ui_controls.record(script.data)
    local committed = ui_controls.rows(data.committed or {})
    assert(#committed == 1, "pickup opens the seeded UID 0 paper body")
    local body = ui_controls.text(committed[1].text)
    local source_fragments = {
        "<h2>Blood Type Compatibility</h2>",
        "<td colspan=\"10\" style=\"background-color: red; color: white;\">Donor</td>",
        "writing-mode: sideways-rl; background-color: blue; color: white;\">Receiver</td>",
        "<td style=\"background-color: red; color: white;\">L</td>",
        "<td style=\"background-color: red; color: white;\">U</td>",
        "<td style=\"background-color: blue; color: white;\">L</td>",
        "<td style=\"background-color: blue; color: white;\">U</td>",
        "Blood types not written above can only receive from the same blood type.",
        "Certain species do not have blood.",
        "</table>",
        "<br/>",
    }
    for _, fragment in ipairs(source_fragments) do
        assert(body:find(fragment, 1, true) ~= nil, "the seeded paper preserves source fragment " .. fragment)
    end
    for _, blood_label in ipairs({ "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "L", "U" }) do
        local donor_cell = "<td style=\"background-color: red; color: white;\">" .. blood_label .. "</td>"
        local receiver_cell = "<td style=\"background-color: blue; color: white;\">" .. blood_label .. "</td>"
        assert(body:find(donor_cell, 1, true) ~= nil, "the donor row preserves " .. blood_label)
        assert(body:find(receiver_cell, 1, true) ~= nil, "the receiver row preserves " .. blood_label)
    end
end

local function move_open_freezer_east(player: number, freezer: SpecObservedTarget): ()
    walk_to(player, 3, 3)
    walk_to(player, 5, 3)
    walk_to(player, 5, 4)

    t.pull(player, 4, 4, freezer)
    t.tick()
    t.move(player, "east")
    t.run_ticks(6)
    t.stop_pull(player)
    t.tick()
    assert(
        t.same_target(assert(t.target_at(player, 5, 4, "sprite:freezer_open")), freezer),
        "the open dense freezer moves east off its stock tile"
    )

    walk_to(player, 6, 3)
    walk_to(player, 4, 3)
end

local function collect_open_stock(player: number): { number }
    local collected: { string } = {}
    local random_types: { number } = {}

    for _, stash in ipairs(STASH_TILES) do
        -- An omitted selector picks the topmost hittable item instead of
        -- skipping a front bag whose silhouette matches a hidden stock item.
        local visible_item = assert(t.target_at(player, 4, 4), "stock has a hittable front item")
        t.click(player, 4, 4, visible_item)
        t.tick()

        local held = assert(t.hands(player).held, "pickup exposes the front stock prototype")
        table.insert(collected, held)
        if held == "paper.blood_types" then
            assert_blood_type_paper(player)
            t.ui_close(player, "writing")
            t.tick()
        end

        walk_to(player, stash.x, stash.y)
        t.drop(player)
        t.tick()
        local stashed_items = t.items_at(stash.x, stash.y)
        assert(#stashed_items == 1 and stashed_items[1] == held, "each picked item occupies its own stash tile")
        local separated = assert(t.target_at(player, stash.x, stash.y), "the separated item is publicly hittable")

        if held == "blood_pack" then
            local contents = assert(t.contents(separated), "the empty bag exposes its vessel")
            assert((contents.blood or 0) == 0, "the base blood pack is empty")
            assert(blood_type(separated) == nil, "the base blood pack has no blood identity")
        elseif held == "blood_pack.random" then
            local kind = blood_type(separated)
            assert(kind ~= nil and kind >= 0 and kind <= 7, "each random bag carries one of eight blood types")
            local contents = assert(t.contents(separated), "the random bag exposes its vessel")
            assert(math.abs((contents.blood or 0) - 5.0) < 1e-12, "each random bag is full")
            local overlays = t.overlays(separated)
            assert(#overlays == 1 and overlays[1] == "bloodpack100", "each random bag wears the full overlay")
            table.insert(random_types, kind)
        elseif TYPED_BLOOD_TYPES[held] ~= nil then
            assert_full_pack(separated, TYPED_BLOOD_TYPES[held], held)
        else
            assert(held == "paper.blood_types", "the visible stock item has a declared freezer prototype")
        end

        walk_to(player, 4, 3)
    end

    assert_item_counts(collected, INITIAL_STOCK, "physically collected stock matches the declared freezer multiset")
    assert(#t.items_at(4, 4) == 0, "the original stock tile is clear after every visible item is collected")
    table.sort(random_types)
    return random_types
end

local player = start_round()

-- The plain freezer keeps its inherited empty stock.
walk_to(player, 3, 2)
walk_to(player, 6, 2)
assert(assert(t.structure_at(7, 2)).state == "closed", "the base freezer starts closed")
assert(#t.items_at(7, 2) == 0, "the base freezer starts without loose stock")
t.click(player, 7, 2, assert(t.target_at(player, 7, 2, "freezer")))
t.tick()
assert(assert(t.structure_at(7, 2)).state == "open", "the base freezer opens normally")
assert(#t.items_at(7, 2) == 0, "opening the base freezer keeps its stock empty")
t.click(player, 7, 2, assert(t.target_at(player, 7, 2, "freezer")))
t.tick()
assert(#t.items_at(7, 2) == 0, "closing the base freezer keeps its stock empty")
walk_to(player, 3, 2)
walk_to(player, 3, 4)

local blood_freezer = open_blood_freezer(player)
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "opened blood freezer")

-- Closing hides the stock; reopening preserves the freezer and exact multiset.
t.click(player, 4, 4, assert(t.target_at(player, 4, 4, "sprite:freezer_open")))
t.tick()
assert(assert(t.structure_at(4, 4)).state == "closed", "the blood freezer closes by player action")
assert(#t.items_at(4, 4) == 0, "closing conceals the stock again")
t.click(player, 4, 4, assert(t.target_at(player, 4, 4, "freezer")))
t.tick()
assert(assert(t.structure_at(4, 4)).state == "open", "the blood freezer reopens")
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "reopened blood freezer")
assert(
    t.same_target(blood_freezer, assert(t.target_at(player, 4, 4, "sprite:freezer_open"))),
    "close and reopen preserve the same blood freezer"
)

move_open_freezer_east(player, blood_freezer)
local first_random_types = collect_open_stock(player)

local repeated_player = start_round()
local repeated_freezer = open_blood_freezer(repeated_player)
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "repeated seeded blood freezer")
move_open_freezer_east(repeated_player, repeated_freezer)
local repeated_random_types = collect_open_stock(repeated_player)
assert(
    #repeated_random_types == #first_random_types,
    "the repeated seeded round has the same number of random bags"
)
for index, kind in ipairs(first_random_types) do
    assert(repeated_random_types[index] == kind, "the repeated seeded round reproduces random bag types")
end

local POWERED_MAP = [==[ (
    name: "powered occupied blood freezer",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [(
        rows: [
            "##############",
            "#............#",
            "#Ga.o........#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "#...oGa......#",
            "#............#",
            "##############",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 5, "player_spawn", { "jobs": "medic" }),
            (4, 4, "freezer.blood"),
            (2, 2, "apc"),
            (6, 16, "apc"),
        ],
        networks: [
            (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
            (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
            (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 5, y: 16, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 5, y: 16, network: "power", channel: "l2", kind: "cable", facing: 15),
            (x: 6, y: 16, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 6, y: 16, network: "power", channel: "l2", kind: "cable", facing: 15),
            (x: 4, y: 16, network: "power", channel: "l1", kind: "cable", facing: 15),
        ],
    )],
)]==]

local function body_on_tile(x: number, y: number, player: number): boolean
    local wanted = t.body_id(player)
    for _, body in ipairs(t.bodies_at(x, y)) do
        if body.id == wanted then
            return true
        end
    end
    return false
end

local function blood_moles(reading: SpecMatterVessel): number
    local blood = reading.contents.blood
    if blood == nil then
        return 0
    end
    return (blood.liquid or 0) + (blood.gas or 0) + (blood.solid or 0)
end

local function assert_blood_reading(x: number, y: number, expected_temperature: number): ()
    local reading = assert(t.vessel_at(x, y, "blood_pack.o_plus"))
    assert(math.abs(blood_moles(reading) - 5.0) < 1e-12, "the O+ blood volume is unchanged")
    assert(
        reading.temp_k + 1e-9 >= expected_temperature,
        "preservation does not cool the O+ blood below its prior temperature at "
            .. x
            .. ","
            .. y
            .. "; prior="
            .. expected_temperature
            .. "; actual="
            .. reading.temp_k
    )
end

t.world(POWERED_MAP, 0)
local power_actor = t.join("assistant")
local power_patient = t.join("medic")
t.run_seconds(1.0)
assert(t.vessel_at(4, 4) == nil, "the closed blood freezer has no internal gas cell")
local live_outlet = assert(t.outlet_at(4, 2))
assert(live_outlet.powered, "the first socket is powered")
local second_outlet = assert(t.outlet_at(4, 16))
assert(second_outlet.powered, "the second socket is independently powered")

local occupied_freezer = assert(t.target_at(power_actor, 4, 4, "freezer"))
local patient_freezer = assert(t.target_at(power_patient, 4, 4, "freezer"))
t.drag(
    power_patient,
    4,
    5,
    t.body_target(power_patient, power_patient),
    4,
    4,
    patient_freezer
)
t.tick()
t.run_ticks(clock.deadline_ticks(2.0) + 1)
assert(t.seen(power_patient, power_patient).offset.y == 14, "the patient climbs onto the closed freezer")

occupied_freezer = open_blood_freezer(power_actor)
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "occupied opening preserves exact blood stock")
local initial_blood_reading = assert(t.vessel_at(4, 4, "blood_pack.o_plus"))
assert(math.abs(blood_moles(initial_blood_reading) - 5.0) < 1e-12, "the initial O+ blood is full")
local initial_blood_temperature = initial_blood_reading.temp_k
t.click(power_actor, 4, 4, assert(t.target_at(power_actor, 4, 4, "sprite:freezer_open")))
t.tick()
assert(assert(t.structure_at(4, 4)).state == "closed", "primary close does not recapture the launched patient")
assert(#t.items_at(4, 4) == 0, "occupied close conceals the unchanged stock")
t.run_seconds(4.0)
assert(body_on_tile(5, 4, power_patient), "the launched patient lands outside on the next tile")
assert(t.seen(power_patient, power_patient).offset.y == 0, "the patient's displacement clears support")
t.move(power_actor, "north")
t.run_seconds(0.25)
t.move(power_actor, "east")
t.run_seconds(0.25)
t.click(power_actor, 4, 4, occupied_freezer)
t.tick()
assert(assert(t.structure_at(4, 4)).state == "open", "the actor reopens for timed entry")
t.use_item(power_patient, assert(t.target_at(power_patient, 4, 4, "sprite:freezer_open")), "alt_primary")
t.tick()
t.run_ticks(clock.deadline_ticks(1.0) + 1)
assert(t.seen(power_patient, power_patient).offset.y == 14, "the patient climbs back onto the open freezer")
local entry_waits = #t.ledger_rows("DoAfterStarted")
t.drag(power_actor, 4, 4, t.body_target(power_actor, power_patient), 4, 4, occupied_freezer)
t.tick()
assert(#t.ledger_rows("DoAfterStarted") > entry_waits, "timed entry starts")
t.run_ticks(clock.deadline_ticks(4.0) + 1)
assert(assert(t.structure_at(4, 4)).state == "closed", "timed entry admits the patient")
assert(not body_on_tile(4, 4, power_patient), "the patient is in closed custody")
assert(t.vessel_at(4, 4) == nil, "occupied closed custody still has no internal gas cell")

t.run_seconds(60)
assert(t.vessel_at(4, 4) == nil, "occupied custody creates no gas vessel")

t.click(power_actor, 4, 4, occupied_freezer)
t.tick()
assert(assert(t.structure_at(4, 4)).state == "open", "external open dumps the occupied freezer")
assert(body_on_tile(4, 4, power_patient), "the patient returns to the freezer tile")
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "occupied reopening returns exact stock")
assert_blood_reading(4, 4, initial_blood_temperature)
t.run_seconds(60)
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "an open freezer leaves exact stock untouched")
assert_blood_reading(4, 4, initial_blood_temperature)

t.world(POWERED_MAP, 0)
power_actor = t.join("assistant")
local power_successor = t.join("medic")
t.run_seconds(1.0)
occupied_freezer = assert(t.target_at(power_actor, 4, 4, "freezer"))
local successor_freezer = assert(t.target_at(power_successor, 4, 4, "freezer"))
t.drag(
    power_successor,
    4,
    5,
    t.body_target(power_successor, power_successor),
    4,
    4,
    successor_freezer
)
t.tick()
t.run_ticks(clock.deadline_ticks(2.0) + 1)
assert(t.seen(power_successor, power_successor).offset.y == 14, "the second patient climbs onto the closed freezer")
t.click(power_actor, 4, 4, occupied_freezer)
t.tick()
assert(assert(t.structure_at(4, 4)).state == "open", "the second run opens for live admission")
assert_item_counts(t.items_at(4, 4), INITIAL_STOCK, "the second run exposes exact stock")
t.click(power_actor, 4, 4, occupied_freezer)
t.tick()
assert(assert(t.structure_at(4, 4)).state == "closed", "the live freezer does not recapture the second patient")
t.run_seconds(4.0)
assert(body_on_tile(5, 4, power_successor), "the second patient lands outside")
assert(t.seen(power_successor, power_successor).offset.y == 0, "the second patient's launch clears support")
t.move(power_actor, "north")
t.run_seconds(0.25)
t.move(power_actor, "east")
t.run_seconds(0.25)
t.click(power_actor, 4, 4, occupied_freezer)
t.tick()
assert(assert(t.structure_at(4, 4)).state == "open", "the second run reopens for timed entry")
t.use_item(power_successor, assert(t.target_at(power_successor, 4, 4, "sprite:freezer_open")), "alt_primary")
t.tick()
t.run_ticks(clock.deadline_ticks(1.0) + 1)
assert(t.seen(power_successor, power_successor).offset.y == 14, "the second patient climbs back onto the freezer")
t.drag(power_actor, 4, 4, t.body_target(power_actor, power_successor), 4, 4, occupied_freezer)
t.tick()
t.run_ticks(clock.deadline_ticks(4.0) + 1)
assert(assert(t.structure_at(4, 4)).state == "closed", "timed entry closes on the second patient")
assert(not body_on_tile(4, 4, power_successor), "the second patient enters closed custody")
t.run_seconds(60)

move_and_settle(power_actor, "west")
move_and_settle(power_actor, "south")
move_and_settle(power_actor, "south")
move_and_settle(power_actor, "east")
t.pull(power_actor, 4, 4, occupied_freezer)
t.tick()
local function pull_south(): ()
    t.move(power_actor, "south")
    t.run_ticks(6)
end
for _ = 1, 5 do
    pull_south()
end
assert(
    t.same_target(assert(t.target_at(power_actor, 4, 9, "freezer")), occupied_freezer),
    "the occupied corded freezer moves beyond both six-tile cords"
)
assert(assert(t.structure_at(4, 9)).state == "closed", "the out-of-range freezer remains closed")
assert(t.vessel_at(4, 9) == nil, "the out-of-range occupied freezer still has no gas cell")
t.run_seconds(62.0)

for _ = 1, 6 do
    pull_south()
end
t.stop_pull(power_actor)
t.tick()
assert(
    t.same_target(assert(t.target_at(power_actor, 4, 15, "freezer")), occupied_freezer),
    "the occupied freezer reaches the second live socket"
)
assert(assert(t.structure_at(4, 15)).state == "closed", "the reconnected freezer remains closed")
assert(t.vessel_at(4, 15) == nil, "the reconnected occupied freezer still has no gas cell")
t.run_seconds(62.0)
t.click(power_actor, 4, 15, occupied_freezer)
t.tick()
assert_item_counts(t.items_at(4, 15), INITIAL_STOCK, "final occupied opening preserves exact stock")
assert_blood_reading(4, 15, initial_blood_temperature)
assert(#t.script_errors() == 0, "occupied custody has no script errors")
print("blood freezer: occupied custody, stock, temperature and cord moves")
