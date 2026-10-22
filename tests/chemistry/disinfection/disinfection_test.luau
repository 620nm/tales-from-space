local actions = require("@helpers/illness_actions")
local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

local STOCK_X, CULTURE_X = 5, 6
local MACHINE_X, MACHINE_Y = 2, 2
local ILLNESS = 0

t.world(
    [==[(
    name: "sampled disinfection",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "##################################################",
                "#g...............................................#",
                "#o.a.............................................#",
                "#................................................#",
                "##################################################",
            ],
            structures: [(2, 1, "player_spawn"), (3, 2, "apc")],
            items: [
                (5, 2, "lab_flask"),
                (6, 2, "bottle.rhinovirus_culture"),
                (7, 2, "bottle"),
                (8, 2, "bottle"),
                (9, 2, "lab_flask"),
                (10, 2, "bottle"),
                (11, 2, "bottle"),
                (12, 2, "bottle"),
                (13, 2, "bottle"),
                (14, 2, "bottle.rhinovirus_culture"),
                (15, 3, "bottle.rhinovirus_culture"),
                (16, 3, "bottle.rhinovirus_culture"),
                (17, 3, "bottle.rhinovirus_culture"),
                (18, 3, "bottle.rhinovirus_culture"),
                (19, 3, "bottle.rhinovirus_culture"),
                (20, 3, "bottle.rhinovirus_culture"),
                (21, 3, "bottle.rhinovirus_culture"),
                (22, 3, "bottle.rhinovirus_culture"),
                (23, 3, "bottle.rhinovirus_culture"),
                (24, 3, "bottle.rhinovirus_culture"),
                (25, 3, "bottle.rhinovirus_culture"),
                (26, 3, "bottle.rhinovirus_culture"),
                (27, 3, "bottle.rhinovirus_culture"),
                (28, 3, "bottle.rhinovirus_culture"),
                (29, 3, "bottle.rhinovirus_culture"),
                (30, 3, "bottle.rhinovirus_culture"),
                (31, 3, "bottle.rhinovirus_culture"),
                (32, 3, "bottle.rhinovirus_culture"),
                (33, 3, "bottle.rhinovirus_culture"),
                (34, 3, "bottle.rhinovirus_culture"),
                (35, 3, "bottle.rhinovirus_culture"),
                (36, 3, "bottle.rhinovirus_culture"),
                (37, 3, "bottle.rhinovirus_culture"),
                (38, 3, "bottle.rhinovirus_culture"),
                (39, 3, "bottle.rhinovirus_culture"),
                (40, 3, "bottle.rhinovirus_culture"),
                (41, 3, "bottle.rhinovirus_culture"),
                (42, 3, "bottle.rhinovirus_culture"),
                (43, 3, "bottle.rhinovirus_culture"),
                (44, 3, "bottle.rhinovirus_culture"),
                (45, 3, "bottle.rhinovirus_culture"),
            ],
            machines: [(2, 2, "chem_dispenser")],
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
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local function go(x: number, y: number)
    local px, py = t.pos(p)
    while px < x do
        t.move(p, "east")
        t.run_ticks(clock.deadline_ticks(0.25))
        px += 1
    end
    while px > x do
        t.move(p, "west")
        t.run_ticks(clock.deadline_ticks(0.25))
        px -= 1
    end
    while py < y do
        t.move(p, "south")
        t.run_ticks(clock.deadline_ticks(0.25))
        py += 1
    end
    while py > y do
        t.move(p, "north")
        t.run_ticks(clock.deadline_ticks(0.25))
        py -= 1
    end
    local reached_x, reached_y = t.pos(p)
    assert(reached_x == x and reached_y == y, ("player reaches %d,%d"):format(x, y))
end

local function target_at(x: number, y: number, id: string): SpecObservedTarget
    return (assert(t.target_at(p, x, y, id), ("%s is at %d,%d"):format(id, x, y)))
end

local function take_at(x: number, y: number, id: string): SpecObservedTarget
    go(x, y - 1)
    assert(t.hands(p).held == nil, "the player has an empty hand before taking a vessel")
    return actions.take(p, x, y, id)
end

local function place_back(x: number, y: number)
    assert(t.hands(p).held ~= nil, "a vessel is held before placing it")
    go(x, y - 1)
    t.move(p, "south")
    t.run_ticks(clock.deadline_ticks(0.25))
    t.drop(p)
    t.run_ticks(2)
    t.move(p, "north")
    t.run_ticks(clock.deadline_ticks(0.25))
end

local function machine_target(): SpecObservedTarget
    return (assert(t.target_at(p, MACHINE_X, MACHINE_Y), "the powered dispenser is present"))
end

local function dispense_held(id: string, substance: string, moles: number)
    assert(moles > 0 and moles <= 1.25, "each dispenser amount fits one real press")
    assert(t.hands(p).held == id, "the intended vessel is held for the dispenser")
    go(MACHINE_X, MACHINE_Y - 1)
    t.click(p, MACHINE_X, MACHINE_Y, machine_target())
    t.run_ticks(2)
    t.click(p, MACHINE_X, MACHINE_Y, machine_target())
    t.run_ticks(2)
    ui_controls.set(p, "amount", moles)
    t.run_ticks(2)
    ui_controls.toggle(p, "dispense", substance)
    t.run_ticks(2)
    ui_controls.toggle(p, "eject")
    t.run_ticks(4)
    assert(t.hands(p).held == id, "the same vessel returns to the player's hand")
end

local function fill_at(x: number, y: number, id: string, substance: string, moles: number)
    take_at(x, y, id)
    dispense_held(id, substance, moles)
    place_back(x, y)
end

local function pour_into(x: number, y: number, id: string): SpecObservedTarget
    local destination = target_at(x, y, id)
    t.click(p, x, y, destination)
    t.run_ticks(2)
    return destination
end

local function pour_stock(
    x: number,
    y: number,
    id: string,
    portions: number
): (number, number, SpecObservedTarget)
    local stock_target = take_at(STOCK_X, 2, "lab_flask")
    t.use_self(p)
    t.run_ticks(2)
    local open_stock = assert(t.vessel(stock_target))
    assert(not open_stock.sealed, "the culture stock flask is opened by its real valve action")
    go(x, y - 1)
    local first_portion_before = t.now()
    local first_target = pour_into(x, y, id)
    local first_portion_after = t.now()
    for _ = 2, portions do
        pour_into(x, y, id)
    end
    t.use_self(p)
    t.run_ticks(2)
    local closed_stock = assert(t.vessel(stock_target))
    assert(closed_stock.sealed, "the culture stock flask is resealed after the real pour")
    place_back(STOCK_X, 2)
    return first_portion_before, first_portion_after, first_target
end

local function pour_bromine(x: number, y: number, id: string, portions: number)
    take_at(13, 2, "bottle")
    go(x, y - 1)
    for _ = 1, portions do
        pour_into(x, y, id)
    end
    place_back(13, 2)
end

local function vessel_at(x: number, y: number, id: string): SpecMatterVessel
    return assert(t.vessel(target_at(x, y, id)), "the target has a native matter read")
end

local function liquid_ml(vessel: SpecMatterVessel, name: string): number
    local phases = (vessel.contents :: any)[name]
    if phases == nil then
        return 0
    end
    return phases.liquid_ml or 0
end

local function total_liquid_ml(vessel: SpecMatterVessel): number
    local total = 0
    for _, phases in pairs(vessel.contents) do
        total += (phases :: any).liquid_ml or 0
    end
    return total
end

local function potency(vessel: SpecMatterVessel, name: string, threshold: number): number
    local total = total_liquid_ml(vessel)
    assert(total > 0, "the native liquid denominator is positive")
    return liquid_ml(vessel, name) / total / threshold
end

local function contagion_arrivals_at(x: number, y: number): number
    local count = 0
    for _, raw in ipairs(t.ledger_rows("rider_arrived")) do
        local row = raw :: any
        local pos = row.pos
        if row.rider == "contagion" and pos ~= nil and pos[1] == x and pos[2] == y then
            count += 1
        end
    end
    return count
end

local function contagion_events(event: string): number
    local count = 0
    for _, raw in ipairs(t.ledger_rows(event)) do
        if (raw :: any).rider == "contagion" then
            count += 1
        end
    end
    return count
end

local function wait_until(tick: number)
    local remaining = tick - t.now()
    if remaining > 0 then
        t.run_ticks(remaining)
    end
    assert(t.now() >= tick, "the simulation reaches the requested tick")
end

local function assert_clears_on_floor(
    x: number,
    y: number,
    target: SpecObservedTarget,
    earliest_contact: number,
    latest_contact: number
)
    go(x, y - 1)
    wait_until(earliest_contact + clock.deadline_ticks(10) - 1)
    assert(actions.has_illness(target, ILLNESS), "one tick before ten seconds remains infected")
    wait_until(latest_contact + clock.deadline_ticks(10) + clock.deadline_ticks(1))
    assert(not actions.has_illness(target, ILLNESS), "a sampled ten-second contact clears")
end

local function assert_clears_held(
    x: number,
    y: number,
    target: SpecObservedTarget,
    earliest_contact: number,
    latest_contact: number
)
    go(x, y)
    wait_until(earliest_contact + clock.deadline_ticks(10) - 1)
    assert(actions.has_illness(target, ILLNESS), "one tick before ten seconds remains infected")
    wait_until(latest_contact + clock.deadline_ticks(10) + clock.deadline_ticks(1))
    assert(not actions.has_illness(target, ILLNESS), "a sampled ten-second contact clears")
end

local function assert_arrived_since(previous: number)
    assert(contagion_events("rider_arrived") > previous, "native rider arrival records the player-created contamination")
end

local function assert_arrived_at_since(x: number, y: number, previous: number)
    assert(contagion_arrivals_at(x, y) > previous, ("native contagion arrival records the pour at %d,%d"):format(x, y))
end

local function assert_cleared_since(previous: number)
    assert(contagion_events("rider_cleared") > previous, "native rider clear records the sampled disinfection")
end

-- The culture stock is built through five 1.25 mol water presses and one
-- real pour from the frozen 45 mL culture bottle.
for _ = 1, 5 do
    fill_at(STOCK_X, 2, "lab_flask", "water", 1.25)
end
take_at(CULTURE_X, 2, "bottle.rhinovirus_culture")
go(STOCK_X, 1)
pour_into(STOCK_X, 2, "lab_flask")
place_back(CULTURE_X, 2)
assert(actions.has_illness(target_at(STOCK_X, 2, "lab_flask"), ILLNESS), "the player-poured stock carries illness zero")
local stock_vessel = vessel_at(STOCK_X, 2, "lab_flask")
assert(liquid_ml(stock_vessel, "blood") > 0, "the culture stock keeps its native blood liquid")
for x = 15, 45 do
    go(x, 2)
    assert(
        actions.has_illness(target_at(x, 3, "bottle.rhinovirus_culture"), ILLNESS),
        ("the map-seeded culture at %d is a live native infection"):format(x)
    )
end
go(CULTURE_X, 1)

-- A true 50-ish percent ethanol sample stays infected beyond the contact
-- interval. Every ingredient arrived through the dispenser or a pour.
fill_at(7, 2, "bottle", "ethanol", 0.125)
local under_arrivals = contagion_events("rider_arrived")
local _, _, under_target = pour_stock(7, 2, "bottle", 1)
assert_arrived_since(under_arrivals)
under_target = take_at(7, 2, "bottle")
local under_mix = assert(t.vessel(under_target))
local under_fraction = liquid_ml(under_mix, "ethanol") / total_liquid_ml(under_mix)
assert(under_fraction >= 0.50 and under_fraction < 0.65, ("the native liquid is about half ethanol: %g"):format(under_fraction))
local under_clear_count = contagion_events("rider_cleared")
t.run_ticks(clock.deadline_ticks(12))
assert(actions.has_illness(under_target, ILLNESS), "half-dose ethanol never clears")
assert(contagion_events("rider_cleared") == under_clear_count, "the half-dose has no native clear event")
place_back(7, 2)

-- Culture arrives first. A qualifying ethanol sample is observed, diluted
-- below threshold for a native clock sample, then restored above 75 percent.
local reset_arrivals = contagion_events("rider_arrived")
local _, _, reset_target = pour_stock(8, 2, "bottle", 1)
assert_arrived_since(reset_arrivals)
reset_target = take_at(8, 2, "bottle")
local first_dose_earliest = t.now()
dispense_held("bottle", "ethanol", 0.35)
local first_mix = assert(t.vessel(reset_target))
local first_ethanol_fraction = liquid_ml(first_mix, "ethanol") / total_liquid_ml(first_mix)
assert(first_ethanol_fraction > 0.75, "the native culture-first sample exceeds 75 percent ethanol")
wait_until(first_dose_earliest + clock.deadline_ticks(6))
assert(actions.has_illness(reset_target, ILLNESS), "the first qualifying sample has not reached ten seconds")
dispense_held("bottle", "water", 0.25)
local diluted = assert(t.vessel(reset_target))
assert(potency(diluted, "ethanol", 0.70) < 1, "the real water press takes the sample below dose")
t.run_ticks(clock.deadline_ticks(2))
assert(actions.has_illness(reset_target, ILLNESS), "a sampled under-dose resets rather than clears")
local restored_earliest = t.now()
dispense_held("bottle", "ethanol", 0.225)
local restored = assert(t.vessel(reset_target))
local restored_ethanol_fraction = liquid_ml(restored, "ethanol") / total_liquid_ml(restored)
assert(restored_ethanol_fraction > 0.75, "the restored sample is natively above 75 percent")
local restored_latest = t.now()
local reset_clear_count = contagion_events("rider_cleared")
assert_clears_held(MACHINE_X, MACHINE_Y - 1, reset_target, restored_earliest, restored_latest)
assert_cleared_since(reset_clear_count)
place_back(8, 2)

-- The 33 map-seeded cultures and the player-seeded stock keep more than one
-- registry page live. This
-- player-created holder is enrolled after that boundary; its second native
-- arrival must preserve the first contact interval through the later page.
-- Ethanol first, then two independent culture bottles carrying the same
-- illness. The 2 L flask separates the liquid dose from shell/headspace.
fill_at(9, 2, "lab_flask", "ethanol", 1.25)
fill_at(9, 2, "lab_flask", "ethanol", 1.25)
local ordered_arrivals = contagion_arrivals_at(9, 2)
local first_earliest, _, headspace_target = pour_stock(9, 2, "lab_flask", 1)
assert_arrived_at_since(9, 2, ordered_arrivals)
go(9, 1)
local first_headspace_mix = assert(t.vessel(headspace_target))
local first_headspace_fraction = liquid_ml(first_headspace_mix, "ethanol") / total_liquid_ml(first_headspace_mix)
assert(potency(first_headspace_mix, "ethanol", 0.70) >= 1, "the first native arrival has a qualifying liquid ethanol dose")
assert(first_headspace_fraction >= 0.70, "the first native liquid fraction is at least 70 percent ethanol")
local first_latest = t.now()
t.run_ticks(clock.deadline_ticks(4))
local second_culture = take_at(14, 2, "bottle.rhinovirus_culture")
assert(actions.has_illness(second_culture, ILLNESS), "the independent culture bottle carries illness zero")
go(9, 1)
local duplicate_before = contagion_arrivals_at(9, 2)
pour_into(9, 2, "lab_flask")
assert_arrived_at_since(9, 2, duplicate_before)
assert(actions.has_illness(headspace_target, ILLNESS), "the independent culture bottle carries illness zero into the holder")
local large_vessel = assert(t.vessel(headspace_target))
local headspace_ethanol_fraction = liquid_ml(large_vessel, "ethanol") / total_liquid_ml(large_vessel)
assert(potency(large_vessel, "ethanol", 0.70) >= 1, "the actual post-arrival liquid fraction remains above the ethanol threshold")
assert(headspace_ethanol_fraction >= 0.70, "the native liquid fraction is at least 70 percent ethanol")
assert(large_vessel.headspace_l > 1.75, "the 2 L shell has substantial measured headspace")
assert(total_liquid_ml(large_vessel) / (large_vessel.volume_l * 1000) < 0.10, "shell volume would falsely make the same ethanol dose subthreshold")
local duplicate_clear_count = contagion_events("rider_cleared")
assert_clears_on_floor(9, 2, headspace_target, first_earliest, first_latest)
assert_cleared_since(duplicate_clear_count)
assert(not actions.has_illness(target_at(9, 2, "lab_flask"), ILLNESS), "the first holder is cleared")
place_back(14, 2)
go(9, 1)

-- A cleared holder is enrolled again by a new real culture pour and clears
-- on a fresh sampled interval, exercising registry removal and re-entry.
take_at(9, 2, "lab_flask")
dispense_held("lab_flask", "ethanol", 0.10)
place_back(9, 2)
local reenroll_arrivals = contagion_events("rider_arrived")
local reenroll_earliest, _, reenroll_target = pour_stock(9, 2, "lab_flask", 1)
assert_arrived_since(reenroll_arrivals)
go(9, 1)
assert(actions.has_illness(reenroll_target, ILLNESS), "the new player pour re-enrolls the cleared holder")
local reenroll_mix = assert(t.vessel(reenroll_target))
local reenroll_ethanol_fraction = liquid_ml(reenroll_mix, "ethanol") / total_liquid_ml(reenroll_mix)
assert(reenroll_ethanol_fraction >= 0.70, "the re-enrolled holder still has a qualifying ethanol fraction")
local reenroll_latest = t.now()
local reenroll_clear_count = contagion_events("rider_cleared")
assert_clears_on_floor(9, 2, reenroll_target, reenroll_earliest, reenroll_latest)
assert_cleared_since(reenroll_clear_count)

-- Two real serial bromine dilutions make an additive fixture that fits a
-- sealed 50 mL bottle. Phase assertions below are native runtime premises.
fill_at(12, 2, "bottle", "bromine", 0.025)
fill_at(12, 2, "bottle", "water", 1.25)
fill_at(12, 2, "bottle", "water", 1.25)
fill_at(12, 2, "bottle", "water", 0.15)
local first_bromine = vessel_at(12, 2, "bottle")
assert(liquid_ml(first_bromine, "bromine") > 0, "the minimum real bromine press remains liquid in its sealed stock bottle")
assert(first_bromine.sealed and first_bromine.headspace_l < 0.005, "the first bromine dilution is sealed with little measured headspace")
fill_at(13, 2, "bottle", "water", 1.25)
fill_at(13, 2, "bottle", "water", 1.25)
take_at(12, 2, "bottle")
go(13, 1)
pour_into(13, 2, "bottle")
place_back(12, 2)
local diluted_bromine = vessel_at(13, 2, "bottle")
assert(liquid_ml(diluted_bromine, "bromine") > 0, "the second sealed dilution keeps measurable liquid bromine")
assert(diluted_bromine.volume_l <= 0.05, "the real stock fits the 50 mL bottle shell")
assert(total_liquid_ml(diluted_bromine) <= 50, "the native liquid volume fits inside the measured 50 mL shell")
assert(diluted_bromine.sealed and diluted_bromine.headspace_l < 0.005, "the second bromine dilution is sealed with little measured headspace")

-- Both agents are individually sub-threshold but add above one. The bottle
-- is nearly full, so the sealed headspace still leaves measurable liquid Br2.
fill_at(10, 2, "bottle", "ethanol", 0.50)
fill_at(10, 2, "bottle", "water", 0.125)
pour_bromine(10, 2, "bottle", 2)
local additive_arrivals = contagion_events("rider_arrived")
local additive_earliest, _, additive_target = pour_stock(10, 2, "bottle", 1)
assert_arrived_since(additive_arrivals)
additive_target = take_at(10, 2, "bottle")
local additive_mix = assert(t.vessel(additive_target))
local ethanol_score = potency(additive_mix, "ethanol", 0.70)
local bromine_score = potency(additive_mix, "bromine", 0.001)
assert(ethanol_score < 1 and bromine_score < 1, "each native liquid agent is individually below threshold")
assert(ethanol_score + bromine_score > 1, "the measured liquid agents add above threshold")
assert(liquid_ml(additive_mix, "bromine") > 0, "the positive fixture has liquid bromine, not headspace gas")
assert(total_liquid_ml(additive_mix) <= 50, "the additive positive fits the bottle shell")
assert(additive_mix.sealed and additive_mix.headspace_l < 0.01, "the positive bottle is sealed and nearly full")
local additive_latest = t.now()
local additive_clear_count = contagion_events("rider_cleared")
wait_until(additive_earliest + clock.deadline_ticks(10) - 1)
assert(actions.has_illness(additive_target, ILLNESS), "the additive sample is still infected before ten seconds")
wait_until(additive_latest + clock.deadline_ticks(10) + clock.deadline_ticks(1))
assert(not actions.has_illness(additive_target, ILLNESS), "the additive positive clears after sampling")
assert_cleared_since(additive_clear_count)
assert(t.now() >= additive_latest + clock.deadline_ticks(10), "the late phase sample is at least ten seconds after the first qualifying native read")
local additive_late = assert(t.vessel(additive_target))
local late_ethanol_score = potency(additive_late, "ethanol", 0.70)
local late_bromine_score = potency(additive_late, "bromine", 0.001)
assert(late_ethanol_score < 1 and late_bromine_score < 1, "both late native agents remain individually below threshold")
assert(late_ethanol_score + late_bromine_score >= 1, "the late native liquid agents still add to at least threshold")
assert(liquid_ml(additive_late, "bromine") > 0, "liquid bromine persists through the late positive sample")
place_back(10, 2)

-- The serially diluted bromine and a smaller ethanol share sum below one;
-- actual liquid phases persist in the nearly full sealed negative bottle.
fill_at(11, 2, "bottle", "ethanol", 0.075)
fill_at(11, 2, "bottle", "water", 1.25)
fill_at(11, 2, "bottle", "water", 0.50)
pour_bromine(11, 2, "bottle", 1)
local negative_arrivals = contagion_events("rider_arrived")
local _, _, negative_target = pour_stock(11, 2, "bottle", 1)
assert_arrived_since(negative_arrivals)
negative_target = take_at(11, 2, "bottle")
local negative_mix = assert(t.vessel(negative_target))
local negative_ethanol = potency(negative_mix, "ethanol", 0.70)
local negative_bromine = potency(negative_mix, "bromine", 0.001)
assert(negative_ethanol < 1 and negative_bromine < 1, "both native agents stay individually below threshold")
assert(negative_ethanol + negative_bromine < 1, "the measured liquid agents sum below threshold")
assert(liquid_ml(negative_mix, "bromine") > 0, "the negative fixture still has liquid bromine")
assert(total_liquid_ml(negative_mix) <= 50, "the additive negative fits the bottle shell")
assert(negative_mix.sealed and negative_mix.headspace_l < 0.01, "the negative bottle is sealed and nearly full")
local negative_clear_count = contagion_events("rider_cleared")
t.run_ticks(clock.deadline_ticks(12))
assert(actions.has_illness(negative_target, ILLNESS), "subthreshold agents leave the culture infected")
assert(contagion_events("rider_cleared") == negative_clear_count, "the additive negative has no native clear event")
local negative_late = assert(t.vessel(negative_target))
assert(liquid_ml(negative_late, "bromine") > 0, "bromine remains liquid through the negative sample interval")
assert(#t.script_errors() == 0, "player-action disinfection specs run without script errors")
