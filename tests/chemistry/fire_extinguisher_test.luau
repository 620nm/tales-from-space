-- The extinguisher's pressure vessel and player-facing valve contract.
-- The item starts with exactly two kilograms of liquid CO2, draws a
-- finite 0.2 kg burst, falls back to the gas tail, and can be charged
-- only from a pure CO2 source while its safety is engaged.
local MOLAR_MASS = 44.0
local INITIAL_MOLES = 2000.0 / MOLAR_MASS

local function vessel(item: SpecObservedTarget): SpecMatterVessel
    return assert(t.vessel(item))
end

local function phase(item: SpecObservedTarget, name: string): number
    local row = vessel(item).contents.co2
    if row == nil then return 0.0 end
    if name == "liquid" then return row.liquid or 0.0 end
    if name == "gas" then return row.gas or 0.0 end
    return row.solid or 0.0
end

local function wait_for_next_burst()
    t.run_ticks(24)
end

t.world(
    [==[ (
    name: "extinguisher pressure bench",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#########",
        "#.......#",
        "#########",
    ],
    blends: {
        "pure_co2_supply": (rows: [("co2", 5000.0)], temperature_k: 300.0, amount: per_tile),
        "mixed_supply": (rows: [("co2", 5000.0), ("o2", 500.0)], temperature_k: 300.0, amount: per_tile),
    },
    items: [(2, 1, "fire_extinguisher")],
    structures: [
        (2, 1, "player_spawn"),
        (3, 1, "canister", { "blend": "pure_co2_supply" }),
        (1, 1, "canister", { "blend": "mixed_supply" }),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.tick()
t.run_seconds(5)

local extinguisher = assert(t.target_at(p, 2, 1, "fire_extinguisher"))
local initial = vessel(extinguisher)
assert(math.abs(initial.moles - INITIAL_MOLES) < 1e-8, "the shell starts with exactly 2 kg of CO2")
assert(phase(extinguisher, "liquid") > 0.5 * INITIAL_MOLES, "most of the fill is liquid CO2")
assert(phase(extinguisher, "gas") > 0.0, "the pressurized shell has a gas headspace")
assert(initial.pressure_kpa > 1000.0 and initial.pressure_kpa < 80 * 101.325, "the fill is finite and pressurized")
assert(initial.sealed, "the nozzle starts sealed")

t.click(p, 2, 1, extinguisher)
t.tick()
assert(t.hands(p).held == "fire_extinguisher", "the player takes the extinguisher")

-- The engaged safety refuses a discharge. The click itself spends the
-- ordinary ranged-use window, so later assertions wait that window out.
local safe_moles = vessel(extinguisher).moles
t.click_component(p, 6, 1, assert(t.component_instance(6, 1, "floor_tiles")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 0, "the safety refuses the burst")
assert(vessel(extinguisher).sealed, "the safety keeps the shell sealed")
assert(math.abs(vessel(extinguisher).moles - safe_moles) < 1e-9, "the safety draws nothing")
t.run_ticks(16)

-- A ranged claim from an empty active hand is refused before it can draw
-- matter or add recoil. The item remains in the other hand.
t.use_self(p)
t.tick()
t.swap_hands(p)
t.tick()
local offhand_moles = vessel(extinguisher).moles
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 0, "an inactive hand cannot discharge")
assert(math.abs(vessel(extinguisher).moles - offhand_moles) < 1e-9, "an inactive hand draws nothing")
t.swap_hands(p)
t.tick()
t.run_ticks(16)

-- One accepted burst uses the active hand, records a pressure discharge,
-- and puts CO2 into the aimed tile.
local before_burst = vessel(extinguisher).moles
local before_room = (assert(t.room_gas(3, 1)).co2 or 0.0)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 1, "a ready burst is recorded")
assert(t.ledger_rows("MatterSprayed")[1].mode == "discharge", "the row names a pressure discharge")
assert(vessel(extinguisher).moles < before_burst, "the burst draws a finite parcel")
t.run_ticks(20)
assert((assert(t.room_gas(3, 1)).co2 or 0.0) > before_room, "CO2 reaches the aimed tile")
assert(vessel(extinguisher).sealed, "discharge leaves the vessel sealed")

-- The pressure and ranged windows both reject an immediate second click
-- without spending a second parcel.
local cooldown_moles = vessel(extinguisher).moles
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "canister")))
t.tick()
assert(#t.ledger_rows("MatterSprayed") == 1, "cooldown refuses a second launch")
assert(math.abs(vessel(extinguisher).moles - cooldown_moles) < 1e-9, "cooldown draws nothing")

-- Nine more 0.2 kg bursts consume the remaining fill. The last launch
-- necessarily uses the gas tail left above the liquid; no tenth-plus
-- parcel can be invented once the shell is empty.
for burst = 2, 10 do
    wait_for_next_burst()
    if burst == 10 then
        assert(phase(extinguisher, "gas") > 0.0, "the final burst has a gas tail to draw")
    end
    t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "canister")))
    t.tick()
end
assert(#t.ledger_rows("MatterSprayed") == 10, "the two kilogram fill permits ten maximum bursts")
assert(vessel(extinguisher).moles < 1e-6, "the tenth burst depletes the vessel")
assert(phase(extinguisher, "liquid") < 1e-6 and phase(extinguisher, "gas") < 1e-6, "liquid then gas both reach empty")

-- A pure CO2 canister raises the vessel strictly. A mixed source is
-- refused before the transfer, even though it contains plenty of CO2.
t.use_self(p)
t.tick()
t.run_ticks(24)
local before_refill = vessel(extinguisher).moles
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "canister")))
t.tick()
assert(vessel(extinguisher).moles > before_refill, "a compatible pure CO2 source refills it")
t.run_ticks(16)
local after_pure = vessel(extinguisher).moles
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "canister")))
t.tick()
assert(math.abs(vessel(extinguisher).moles - after_pure) < 1e-9, "a mixed source is rejected")
