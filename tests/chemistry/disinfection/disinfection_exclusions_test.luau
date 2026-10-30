local actions = require("@helpers/illness_actions")
local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

local ILLNESS = 0
local MACHINE_X, MACHINE_Y = 2, 3
local DROP_X, DROP_Y = 19, 4
local ETHANOL_THRESHOLD = 0.70
local HALOGEN_THRESHOLD = 0.001
local IODINE_THRESHOLD = 0.01
local SYRINGE_STROKE_MOL = 0.125
local MOLE_EPSILON = 1e-6

type ContaminatedVessel = {
    target: SpecObservedTarget,
    owner: string,
}

-- Preserve the seed-3 named cohort and join order from rhinovirus_test.luau;
-- its engineer is susceptible before the real syringe injection below.
t.world(
    [==[(
    name: "liquid disinfection exclusions",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "######################",
                "#....................#",
                "#g...................#",
                "#o.a.................#",
                "#....................#",
                "######################",
            ],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (3, 1, "player_spawn", { "jobs": "engineer" }),
                (18, 1, "player_spawn", { "jobs": "assistant" }),
                (20, 1, "player_spawn", { "jobs": "captain" }),
                (3, 3, "apc"),
            ],
            items: [
                (5, 2, "syringe"),
                (6, 2, "bottle.rhinovirus_culture"),
                (7, 2, "bottle.rhinovirus_culture"),
                (8, 2, "bottle.rhinovirus_culture"),
                (9, 2, "bottle.rhinovirus_culture"),
                (10, 2, "bottle"),
                (11, 2, "bottle"),
                (12, 2, "water_bottle"),
                (13, 2, "bottle.iodine"),
                (14, 2, "syringe"),
                (15, 2, "syringe"),
                (16, 2, "bottle"),
            ],
            machines: [(2, 3, "chem_dispenser")],
            networks: [
                (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    3
)

t.set_environment({ sink_k = 293.15, insolation = 0 })
local medic = t.join("medic")
t.join("assistant")
local engineer = t.join("engineer")
t.join("captain")
t.run_ticks(3)
t.run_seconds(3)

local function go(x: number, y: number): ()
    local px, py = t.pos(medic)
    if py == 1 and (px ~= x or y > 1) then
        t.move(medic, "south")
        t.run_ticks(clock.deadline_ticks(0.25))
        py += 1
    end
    while px < x do
        t.move(medic, "east")
        t.run_ticks(clock.deadline_ticks(0.25))
        px += 1
    end
    while px > x do
        t.move(medic, "west")
        t.run_ticks(clock.deadline_ticks(0.25))
        px -= 1
    end
    while py < y do
        t.move(medic, "south")
        t.run_ticks(clock.deadline_ticks(0.25))
        py += 1
    end
    while py > y do
        t.move(medic, "north")
        t.run_ticks(clock.deadline_ticks(0.25))
        py -= 1
    end
    local arrived_x, arrived_y = t.pos(medic)
    assert(arrived_x == x and arrived_y == y, "the medic reaches the requested tile")
end

local function target_at(x: number, y: number, id: string): SpecObservedTarget
    local target = assert(t.target_at(medic, x, y, id), id .. " is visible at the requested tile")
    return target
end

local function take_at(x: number, y: number, id: string): SpecObservedTarget
    go(x, y - 1)
    assert(t.hands(medic).held == nil, "the medic has an empty hand before taking a fixture item")
    return actions.take(medic, x, y, id)
end

local function drop_at(x: number, y: number): ()
    assert(t.hands(medic).held ~= nil, "a real held item is set down on the clear pad")
    go(x, y - 1)
    t.move(medic, "south")
    t.run_ticks(clock.deadline_ticks(0.25))
    t.drop(medic)
    t.run_ticks(2)
    t.move(medic, "north")
    t.run_ticks(clock.deadline_ticks(0.25))
end

local function drop_here(): ()
    assert(t.hands(medic).held ~= nil, "the held culture bottle is released before retrieval")
    t.drop(medic)
    t.run_ticks(2)
end

local function machine_target(): SpecObservedTarget
    local target = assert(t.target_at(medic, MACHINE_X, MACHINE_Y), "the powered dispenser is visible")
    return target
end

local function dispense_held(id: string, substance: string, moles: number): ()
    assert(moles > 0 and moles <= 1.25, "the requested amount fits one real dispenser press")
    assert(t.hands(medic).held == id, "the intended vessel is in the medic's hand")
    go(MACHINE_X, MACHINE_Y - 1)
    t.click(medic, MACHINE_X, MACHINE_Y, machine_target())
    t.run_ticks(2)
    t.click(medic, MACHINE_X, MACHINE_Y, machine_target())
    t.run_ticks(2)
    ui_controls.set(medic, "amount", moles)
    t.run_ticks(2)
    ui_controls.toggle(medic, "dispense", substance)
    t.run_ticks(2)
    ui_controls.toggle(medic, "eject")
    t.run_ticks(4)
    assert(t.hands(medic).held == id, "the same vessel returns from the dispenser")
end

local function place_back(x: number, y: number, id: string): ()
    assert(t.hands(medic).held == id, "the filled vessel is held before it is returned")
    go(x, y - 1)
    t.move(medic, "south")
    t.run_ticks(clock.deadline_ticks(0.25))
    t.drop(medic)
    t.run_ticks(2)
    t.move(medic, "north")
    t.run_ticks(clock.deadline_ticks(0.25))
end

local function fill_at(x: number, y: number, id: string, substance: string, moles: number): ()
    take_at(x, y, id)
    dispense_held(id, substance, moles)
    place_back(x, y, id)
end

local function vessel_at(target: SpecObservedTarget): SpecMatterVessel
    local reading = assert(t.vessel(target), "the observed vessel has a native matter reading")
    return reading
end

local function phases(vessel: SpecMatterVessel, name: string): SpecMatterContents
    local found = vessel.contents[name]
    if found ~= nil then
        return found
    end
    return { name = name }
end

local function total_liquid_ml(vessel: SpecMatterVessel): number
    local total = 0
    for _, row in pairs(vessel.contents) do
        total += row.liquid_ml or 0
    end
    return total
end

local function liquid_fraction(vessel: SpecMatterVessel, name: string): number
    local total = total_liquid_ml(vessel)
    assert(total > 0, "the observed body or vessel has actual liquid in its denominator")
    return (phases(vessel, name).liquid_ml or 0) / total
end

local function total_moles(vessel: SpecMatterVessel, name: string): number
    local row = phases(vessel, name)
    return (row.solid or 0) + (row.liquid or 0) + (row.gas or 0)
end

local function latest_ledger_seq(event: string): number
    local latest = 0
    for _, row in ipairs(t.ledger_rows(event)) do
        latest = math.max(latest, row.seq)
    end
    return latest
end

local function draw_syringe_stroke(
    source_x: number,
    source_y: number,
    source: SpecObservedTarget,
    syringe: SpecObservedTarget,
    name: string
): number
    local refreshed_source = t.target_at(medic, source_x, source_y, source)
    assert(
        refreshed_source ~= nil,
        "the same source entity is currently observed at its tile immediately before drawing"
    )
    local source_vessel_before = vessel_at(refreshed_source)
    assert((phases(source_vessel_before, name).liquid_ml or 0) > 0, "the native source has actual liquid before drawing")
    local source_before = total_moles(source_vessel_before, name)
    local syringe_before = total_moles(vessel_at(syringe), name)
    actions.draw_from_vessel(medic, source_x, source_y, refreshed_source)
    local source_vessel_after = vessel_at(refreshed_source)
    local source_after = total_moles(source_vessel_after, name)
    local stroke = vessel_at(syringe)
    local syringe_after = total_moles(stroke, name)
    local source_delta = source_before - source_after
    local syringe_delta = syringe_after - syringe_before
    assert(
        math.abs(source_delta - SYRINGE_STROKE_MOL) < MOLE_EPSILON,
        "the real draw removes 0.125 mol from the source across native phases"
    )
    assert(
        math.abs(syringe_delta - source_delta) < MOLE_EPSILON,
        "the real draw's syringe gain matches the source's measured native-mole loss"
    )
    assert((phases(source_vessel_after, name).liquid_ml or 0) > 0, "the native source retains actual liquid after drawing")
    assert((phases(stroke, name).liquid_ml or 0) > 0, "the syringe stroke has actual liquid volume")
    return syringe_delta
end

local function is_core_contagion_clear(
    row: SpecLedgerRow,
    owner: string,
    x: number?,
    y: number?
): boolean
    if row.rider ~= "contagion" or row.actor.kind ~= "script" or row.from ~= nil or row.owner ~= owner then
        return false
    end
    if x ~= nil or y ~= nil then
        local pos = row.pos
        return pos ~= nil and x ~= nil and y ~= nil and pos[1] == x and pos[2] == y
    end
    return true
end

local function core_contagion_clears_since(
    owner: string,
    after_seq: number,
    x: number?,
    y: number?
): number
    local count = 0
    for _, row in ipairs(t.ledger_rows("rider_cleared")) do
        if row.seq > after_seq and is_core_contagion_clear(row, owner, x, y) then
            count += 1
        end
    end
    return count
end

local function assert_no_core_contagion_clear(
    owner: string,
    after_seq: number,
    x: number,
    y: number
): ()
    assert(
        core_contagion_clears_since(owner, after_seq, x, y) == 0,
        "no explicit native contagion clear targets the matching owner at its fixed tile"
    )
end

local function injected_moles_since(
    after_seq: number,
    owner: string,
    x: number,
    y: number
): number
    local count = 0
    local total = 0
    for _, row in ipairs(t.ledger_rows("injected")) do
        local pos = row.pos
        if row.seq > after_seq and row.actor.kind == "script"
            and row.target == owner and pos ~= nil and pos[1] == x and pos[2] == y
        then
            assert(type(row.moles) == "number" and row.moles > 0, "native injection records positive moved moles")
            count += 1
            total += row.moles
        end
    end
    assert(count == 1, "one real body injection has one matching native delivery receipt")
    return total
end

local function injected_target_since(after_seq: number, x: number, y: number): string
    local count = 0
    local owner: string? = nil
    for _, row in ipairs(t.ledger_rows("injected")) do
        local pos = row.pos
        if row.seq > after_seq and row.actor.kind == "script"
            and pos ~= nil and pos[1] == x and pos[2] == y
        then
            assert(type(row.target) == "string" and #row.target > 0, "native injection names its actual body target")
            assert(type(row.moles) == "number" and row.moles > 0, "native culture injection records positive moved moles")
            owner = row.target
            count += 1
        end
    end
    assert(count == 1 and owner ~= nil, "one real culture injection identifies the engineer body owner")
    return owner
end

local function inject_syringe_into_engineer(target: SpecObservedTarget, name: string, owner: string): number
    actions.flip_syringe(medic)
    go(4, 1)
    local syringe_before = total_moles(vessel_at(target), name)
    local injection_seq = latest_ledger_seq("injected")
    actions.inject_into_body(medic, engineer)
    local syringe_after = total_moles(vessel_at(target), name)
    local moved = injected_moles_since(injection_seq, owner, 3, 1)
    assert(
        math.abs((syringe_before - syringe_after) - moved) < MOLE_EPSILON,
        "native injected moles match the syringe's measured native-mole loss"
    )
    actions.flip_syringe(medic)
    return moved
end

local function contagion_arrivals_at(x: number, y: number): number
    local count = 0
    for _, row in ipairs(t.ledger_rows("rider_arrived")) do
        local pos = row.pos
        if type(row.rider) == "string" and row.rider == "contagion"
            and pos ~= nil and pos[1] == x and pos[2] == y
        then
            count += 1
        end
    end
    return count
end

local function latest_contagion_arrival_at(x: number, y: number): number
    local latest = 0
    for _, row in ipairs(t.ledger_rows("rider_arrived")) do
        local pos = row.pos
        if type(row.rider) == "string" and row.rider == "contagion"
            and pos ~= nil and pos[1] == x and pos[2] == y
        then
            latest = math.max(latest, row.tick)
        end
    end
    assert(latest > 0, "the native ledger records contagion arrival at the poured destination")
    return latest
end

local function pour_culture(
    source_x: number,
    target_x: number,
    target_id: string
): ContaminatedVessel
    local source = take_at(source_x, 2, "bottle.rhinovirus_culture")
    assert(actions.has_illness(source, ILLNESS), "the real source bottle carries the seeded culture")
    go(target_x, 1)
    local destination = target_at(target_x, 2, target_id)
    local arrivals_before = contagion_arrivals_at(target_x, 2)
    local pour_seq = latest_ledger_seq("poured")
    t.click(medic, target_x, 2, destination)
    t.run_ticks(2)
    assert(contagion_arrivals_at(target_x, 2) > arrivals_before, "a real culture pour records native arrival")
    assert(actions.has_illness(destination, ILLNESS), "the poured destination actually carries contagion")
    local owner: string? = nil
    local owner_rows = 0
    for _, row in ipairs(t.ledger_rows("poured")) do
        local pos = row.pos
        if row.seq > pour_seq and row.actor.kind == "script" and pos ~= nil
            and pos[1] == target_x and pos[2] == 2
        then
            assert(type(row.to) == "string" and #row.to > 0, "native pour receipt names its actual destination owner")
            owner = row.to
            owner_rows += 1
        end
    end
    assert(owner_rows == 1 and owner ~= nil, "one native pour receipt identifies the contaminated vessel owner")
    return { target = destination, owner = owner }
end

local engineer_x, engineer_y = t.pos(engineer)
assert(engineer_x == 3 and engineer_y == 1, "the seeded engineer begins at the fixture's fixed body tile")
local clears_before_body_doses = latest_ledger_seq("rider_cleared")

-- Real culture syringe: this is the same seed and named join order used by
-- bodies/rhinovirus_test.luau, with the engineer infected by a player action.
local culture_syringe = take_at(5, 2, "syringe")
local infection_source = target_at(6, 2, "bottle.rhinovirus_culture")
actions.draw_from_vessel(medic, 6, 2, infection_source)
assert(actions.has_illness(culture_syringe, ILLNESS), "the real culture draw makes the syringe infectious")
actions.flip_syringe(medic)
go(4, 1)
local infection_injected_seq = latest_ledger_seq("injected")
actions.inject_into_body(medic, engineer)
local engineer_owner = injected_target_since(infection_injected_seq, engineer_x, engineer_y)
assert(actions.has_illness(t.body_target(medic, engineer), ILLNESS), "the engineer is infected through a real culture-syringe injection")
drop_at(DROP_X, DROP_Y)

-- These real 0.125 mol ethanol strokes are positive liquid in an infected
-- body, but not a concentration-based body-exclusion proof. human_chest.luau
-- 44-54 sets normal blood to 5.6 L inside a 6 L shell, leaving 400 ml:
-- even a full shell gives 400 / 6000 = 0.06667, below 70%.
local max_added_ml = 6000 - 5600
assert(
    max_added_ml / (5600 + max_added_ml) < ETHANOL_THRESHOLD,
    "normal blood leaves no geometry for 70% body ethanol"
)
fill_at(10, 2, "bottle", "ethanol", 0.5)
local ethanol_target = target_at(10, 2, "bottle")
local ethanol_source_vessel = vessel_at(ethanol_target)
assert((phases(ethanol_source_vessel, "ethanol").liquid_ml or 0) > 0, "the dispenser leaves actual ethanol liquid in its bottle")
assert(math.abs(total_moles(ethanol_source_vessel, "ethanol") - 0.5) < MOLE_EPSILON, "the bottle holds 0.5 mol ethanol across native phases")
local ethanol_syringe = take_at(14, 2, "syringe")
go(10, 1)
draw_syringe_stroke(10, 2, ethanol_target, ethanol_syringe, "ethanol")
local first_ethanol_delivery = inject_syringe_into_engineer(ethanol_syringe, "ethanol", engineer_owner)
assert(first_ethanol_delivery > 0, "the first actual ethanol delivery is positive")
go(10, 1)
draw_syringe_stroke(10, 2, ethanol_target, ethanol_syringe, "ethanol")
local second_ethanol_delivery = inject_syringe_into_engineer(ethanol_syringe, "ethanol", engineer_owner)
assert(second_ethanol_delivery > 0, "the second actual ethanol delivery is positive")

local ethanol_window_start = t.now()
for second = 0, 12 do
    if second > 0 then
        t.run_seconds(1)
    end
    local body = assert(t.body(engineer), "the injected engineer body is observable")
    local body_x, body_y = t.pos(engineer)
    assert(body_x == 3 and body_y == 1, "the engineer remains at the fixed body-clear observation tile")
    assert(body.animate and body.posture == "standing", "the body stays animated and standing through ethanol observation")
    local observed_body = t.body_target(medic, engineer)
    assert(actions.has_illness(observed_body, ILLNESS), "the body infection persists through ethanol observation")
    local body_vessel = vessel_at(observed_body)
    local ethanol = phases(body_vessel, "ethanol")
    assert((ethanol.liquid_ml or 0) > 0, "actual ethanol liquid remains in the bloodstream")
    local fraction = liquid_fraction(body_vessel, "ethanol")
    assert(fraction > 0 and fraction < ETHANOL_THRESHOLD, "the actual bloodstream ethanol fraction remains below 70%")
    assert_no_core_contagion_clear(engineer_owner, clears_before_body_doses, 3, 1)
end
assert(t.now() - ethanol_window_start >= clock.deadline_ticks(12), "body ethanol is observed for at least twelve seconds")
drop_at(DROP_X, DROP_Y)

-- A separate clean syringe and a real 0.5 mol bromine bottle keep the
-- observed bloodstream fraction over the liquid 0.1% threshold.
fill_at(16, 2, "bottle", "bromine", 0.5)
local bromine_source = target_at(16, 2, "bottle")
local bromine_source_vessel = vessel_at(bromine_source)
assert(bromine_source_vessel.sealed, "the dispenser-filled bromine source remains sealed")
assert((phases(bromine_source_vessel, "bromine").liquid_ml or 0) > 0, "the bromine source has actual liquid")
assert(math.abs(total_moles(bromine_source_vessel, "bromine") - 0.5) < MOLE_EPSILON, "the bottle holds 0.5 mol bromine across native phases")
local bromine_syringe = take_at(15, 2, "syringe")
go(16, 1)
draw_syringe_stroke(16, 2, bromine_source, bromine_syringe, "bromine")
local first_bromine_delivery = inject_syringe_into_engineer(bromine_syringe, "bromine", engineer_owner)
assert(first_bromine_delivery > 0, "the first actual bromine delivery is positive")
go(16, 1)
draw_syringe_stroke(16, 2, bromine_source, bromine_syringe, "bromine")
local second_bromine_delivery = inject_syringe_into_engineer(bromine_syringe, "bromine", engineer_owner)
assert(second_bromine_delivery > 0, "the second actual bromine delivery is positive")

local bromine_window_start = t.now()
for second = 0, 12 do
    if second > 0 then
        t.run_seconds(1)
    end
    local body = assert(t.body(engineer), "the bromine-dosed engineer body is observable")
    local body_x, body_y = t.pos(engineer)
    assert(body_x == 3 and body_y == 1, "the engineer remains at the fixed body-clear observation tile")
    assert(body.animate and body.posture == "standing", "the body stays animated and standing during bromine observation")
    local observed_body = t.body_target(medic, engineer)
    assert(actions.has_illness(observed_body, ILLNESS), "the body infection persists during bromine observation")
    local body_vessel = vessel_at(observed_body)
    local bromine = phases(body_vessel, "bromine")
    assert((bromine.liquid_ml or 0) > 0, "actual liquid bromine is present in the bloodstream")
    assert(
        liquid_fraction(body_vessel, "bromine") >= HALOGEN_THRESHOLD,
        "every one-second bloodstream sample remains at or above 0.1% liquid bromine"
    )
    assert_no_core_contagion_clear(engineer_owner, clears_before_body_doses, 3, 1)
end
assert(t.now() - bromine_window_start >= clock.deadline_ticks(12), "above-threshold body bromine is observed for twelve seconds")
drop_at(DROP_X, DROP_Y)
assert_no_core_contagion_clear(engineer_owner, clears_before_body_doses, 3, 1)

-- Fluorine is present only as gas in this sealed native water_bottle. The
-- real culture pour is capacity-trimmed; phase readings, not its requested
-- pour units, determine whether any eligible liquid fluorine exists.
local gas_clear_baseline = latest_ledger_seq("rider_cleared")
go(12, 1)
local gas_target = target_at(12, 2, "water_bottle")
local gas_before = vessel_at(gas_target)
assert(gas_before.sealed, "the map water bottle begins sealed")
assert((phases(gas_before, "water").liquid_ml or 0) > 0, "the map water bottle begins with liquid water")
local initial_fluorine = phases(gas_before, "fluorine")
assert((initial_fluorine.gas or 0) > 0, "the map water bottle begins with actual fluorine gas")
assert((initial_fluorine.liquid or 0) == 0 and (initial_fluorine.solid or 0) == 0, "the map fluorine is nonliquid")
local gas_contaminated = pour_culture(8, 12, "water_bottle")
drop_at(DROP_X, DROP_Y)
local fluorine_window_start = t.now()
for second = 0, 12 do
    if second > 0 then
        t.run_seconds(1)
    end
    local mixture = vessel_at(gas_contaminated.target)
    assert(mixture.sealed, "the real culture pour leaves the water bottle sealed")
    local fluorine = phases(mixture, "fluorine")
    assert((fluorine.gas or 0) > 0, "native fluorine remains in the gas phase")
    assert((fluorine.liquid or 0) == 0 and (fluorine.solid or 0) == 0, "fluorine has no liquid or solid phase")
    assert((fluorine.liquid_ml or 0) == 0, "no eligible liquid fluorine is present")
    assert(liquid_fraction(mixture, "fluorine") < HALOGEN_THRESHOLD, "actual liquid fluorine stays below its threshold")
    assert(actions.has_illness(gas_contaminated.target, ILLNESS), "the sealed gas-only fluorine sample stays infected")
    assert_no_core_contagion_clear(gas_contaminated.owner, gas_clear_baseline, 12, 2)
end
assert(t.now() - fluorine_window_start >= clock.deadline_ticks(12), "gas-only fluorine is observed for twelve seconds")

-- Iodine remains native solid with legitimate trace vapor while the actual
-- liquid iodine dose stays zero through the full native contact interval.
local iodine_clear_baseline = latest_ledger_seq("rider_cleared")
go(13, 1)
local iodine_target = target_at(13, 2, "bottle.iodine")
local iodine_before = vessel_at(iodine_target)
assert(iodine_before.sealed, "the map iodine bottle begins sealed")
local iodine_at_rest = phases(iodine_before, "iodine")
assert((iodine_at_rest.solid or 0) > 0.12, "the map iodine starts as native solid")
assert((iodine_at_rest.liquid or 0) < 1e-9 and (iodine_at_rest.gas or 0) > 0, "the map iodine has no liquid and has trace vapor")
local iodine_contaminated = pour_culture(9, 13, "bottle.iodine")
drop_at(DROP_X, DROP_Y)
local iodine_window_start = t.now()
for second = 0, 12 do
    if second > 0 then
        t.run_seconds(1)
    end
    local mixture = vessel_at(iodine_contaminated.target)
    assert(mixture.sealed, "the real culture pour leaves the iodine bottle sealed")
    local iodine = phases(mixture, "iodine")
    assert((iodine.solid or 0) > 0.12, "native iodine remains solid")
    assert((iodine.liquid or 0) < 1e-9 and (iodine.liquid_ml or 0) == 0, "native iodine has no liquid phase")
    assert((iodine.gas or 0) > 0, "the solid iodine keeps its legitimate trace vapor")
    assert(liquid_fraction(mixture, "iodine") < IODINE_THRESHOLD, "actual liquid iodine stays below its threshold")
    assert(actions.has_illness(iodine_contaminated.target, ILLNESS), "the solid-with-trace-vapor sample stays infected")
    assert_no_core_contagion_clear(iodine_contaminated.owner, iodine_clear_baseline, 13, 2)
end
assert(t.now() - iodine_window_start >= clock.deadline_ticks(12), "nonliquid iodine is observed for twelve seconds")
assert_no_core_contagion_clear(engineer_owner, clears_before_body_doses, 3, 1)

-- A real worn medic backpack is the positive container control. Native
-- moles/volume and actual retained phases establish the qualifying liquid
-- fraction after the bottle's single capacity-trimmed culture pour.
assert(t.worn(medic).back == "backpack", "the medic wears the real outfit backpack")
fill_at(11, 2, "bottle", "ethanol", 0.65)
local positive_clear_baseline = latest_ledger_seq("rider_cleared")
local positive_contaminated = pour_culture(7, 11, "bottle")
local positive_arrival_tick = latest_contagion_arrival_at(11, 2)
local positive_vessel = vessel_at(positive_contaminated.target)
assert(positive_vessel.sealed, "the qualifying ethanol bottle remains sealed")
assert(liquid_fraction(positive_vessel, "ethanol") >= ETHANOL_THRESHOLD, "actual retained liquid ethanol is qualifying before storage")
assert(actions.has_illness(positive_contaminated.target, ILLNESS), "native contagion is present before storage")
assert_no_core_contagion_clear(positive_contaminated.owner, positive_clear_baseline, 11, 2)
assert(t.now() - positive_arrival_tick < clock.deadline_ticks(10), "the infected bottle is stowed before ten seconds expire")

-- Drop only the empty source at the medic's feet, then stow the infected
-- target. During the wait below, inspect only the public storage receipt
-- and native ledger; never read the nested vessel before retrieval.
drop_here()
local stowed_target = actions.take(medic, 11, 2, "bottle")
assert_no_core_contagion_clear(positive_contaminated.owner, positive_clear_baseline, 11, 2)
local clears_before_stow = latest_ledger_seq("rider_cleared")
local bag_before = t.stored(medic, "back")
for _, id in ipairs(bag_before) do
    assert(id ~= "bottle", "the medic backpack has no preexisting bottle to confuse the receipt")
end
t.store(medic, "back")
t.tick()
assert(t.hands(medic).held == nil, "the infected bottle leaves the hand for the real backpack")
local bag_after = t.stored(medic, "back")
assert(#bag_after == #bag_before + 1, "t.stored records one new backpack item")
local nested_bottle_index: number? = nil
for index, id in ipairs(bag_after) do
    if id == "bottle" then
        nested_bottle_index = index
    end
end
local nested_bottle = assert(nested_bottle_index, "t.stored proves the infected bottle is nested")
local stowed_at = t.now()
t.run_seconds(12)
local before_retrieval = t.now()
assert(before_retrieval - stowed_at >= clock.deadline_ticks(10), "the infected bottle stays nested past the native contact interval")
local clear_tick: number? = nil
for _, row in ipairs(t.ledger_rows("rider_cleared")) do
    if row.seq > clears_before_stow
        and is_core_contagion_clear(row, positive_contaminated.owner, nil, nil)
        and row.tick >= stowed_at and row.tick <= before_retrieval
    then
        clear_tick = row.tick
    end
end
assert(clear_tick ~= nil, "a native contagion clear tick lands inside the stow-to-take window")
t.take_from(medic, "back", nested_bottle)
t.tick()
assert(t.hands(medic).held == "bottle", "the real t.take_from retrieves the same bottle")
assert(not actions.has_illness(stowed_target, ILLNESS), "the retrieved bottle is already natively cleared")
