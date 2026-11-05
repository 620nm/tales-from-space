-- The gas turbine's arithmetic, tg's verbatim: how much gas one stage
-- pumps into the next and the work it does on the way (`transfer_gases`,
-- turbine.dm:142-162), and the shaft speed and grid watts the ejected gas
-- makes (:677-685). Each stage is a section read as a gas holder
-- (`sim.matter_read`); lib/power/gas_turbine_turns.luau sequences the passes.
local gas_turbine_stages = {}

-- The three stages a pass reads, in flow order.
export type Stages = { compressor: MatterRead, rotor: MatterRead, outlet: MatterRead }

-- R_IDEAL_GAS_EQUATION, kPa*L/(K*mol) (code/__DEFINES/atmospherics/atmos_core.dm:23).
local R = 8.31
-- MOLAR_ACCURACY, the QUANTIZE step (atmos_core.dm:50; atmos_mob_interaction.dm:14).
local MOLAR_ACCURACY = 1e-4
-- MINIMUM_TURBINE_PRESSURE, the PRESSURE_MAX floor (turbine.dm:2-4).
local MINIMUM_KPA = 0.01
-- `gas_pressure_calculate` moves nothing under this head (gas_mixture.dm:600).
local MIN_PUMP_DELTA_KPA = 0.01
-- code/__DEFINES/turbine_defines.dm:10-24.
local RPM_CONVERSION = 15
local RECTIFICATION = 0.3
local WORK_CONVERSION = 0.01
local HEAT_CONVERSION = 0.005
local COMPRESSOR_STATOR_INTERACTION = 0.15

-- DM's `round(x, step)`: the nearest multiple of `step`.
function gas_turbine_stages.round_to(x: number, step: number): number
    return math.floor(x / step + 0.5) * step
end

local round_to = gas_turbine_stages.round_to

-- The three sections' gas, or nil while any of them holds none.
function gas_turbine_stages.read(compressor: Handle, rotor: Handle, outlet: Handle): Stages?
    local first, second, third =
        sim.matter_read(compressor), sim.matter_read(rotor), sim.matter_read(outlet)
    if first == nil or second == nil or third == nil then
        return nil
    end
    return { compressor = first, rotor = second, outlet = third }
end

-- `PRESSURE_MAX` of a holder's pressure.
function gas_turbine_stages.floored_kpa(reading: MatterRead): number
    return math.max(reading.pressure_kpa, MINIMUM_KPA)
end

-- `gas_pressure_calculate`'s plain form (gas_mixture.dm:584-604): the moles
-- that bring `output` to `target_kpa`. The engine's pumps skip tg's
-- quadratic branch too (its docs/atmos/in-line-machines.md).
function gas_turbine_stages.pump_moles(
    input: MatterRead,
    output: MatterRead,
    target_kpa: number
): number
    if input.moles <= 0 or input.temp_k <= 0 then
        return 0
    end
    local delta = if output.temp_k <= 0 or output.moles <= 0
        then target_kpa
        else target_kpa - output.pressure_kpa
    if delta < MIN_PUMP_DELTA_KPA then
        return 0
    end
    return math.min(delta * output.volume_l / (input.temp_k * R), input.moles)
end

-- `transfer_gases` (turbine.dm:142-162): pump `input` into `output` at
-- `input`'s pressure times `intake`, heat `output` by the work, and answer
-- the work less `remove`. The parcel keeps its source's volume (`remove`,
-- gas_mixture.dm:206).
function gas_turbine_stages.transfer(
    from: MatterOwner | Handle,
    input: MatterRead,
    to: Handle,
    output: MatterRead,
    remove: number,
    intake: number
): number
    local moles = gas_turbine_stages.pump_moles(input, output, input.pressure_kpa * intake)
    if moles <= 0 then
        return 0
    end
    local parcel_kpa = math.max(moles * R * input.temp_k / input.volume_l, MINIMUM_KPA)
    local work = round_to(moles, MOLAR_ACCURACY)
        * R
        * input.temp_k
        * math.log(
            (input.volume_l * parcel_kpa)
                / (output.volume_l * gas_turbine_stages.floored_kpa(output))
        )
        * WORK_CONVERSION
    work -= remove
    sim.matter.transfer({ from = from, to = to, amount = moles, phases = { "gas" } })
    -- tg caps the work by the output's heat and floors it at TCMB (:157-161);
    -- a reading carries no heat capacity, so the engine's energy floor stands in.
    sim.matter.add_energy({ owner = to, joules = work * HEAT_CONVERSION })
    return work
end

-- The ejected gas's work (turbine.dm:677-679): its expansion from the
-- compressor's pressure, less the compressor's share and the outlet's work.
function gas_turbine_stages.ejected_work(
    moles: number,
    outlet: MatterRead,
    compressor_kpa: number,
    compressor_work: number,
    turbine_work: number
): number
    local ejected_kpa = math.max(moles * R * outlet.temp_k / outlet.volume_l, MINIMUM_KPA)
    local work = round_to(moles, MOLAR_ACCURACY)
        * R
        * outlet.temp_k
        * math.log(compressor_kpa / ejected_kpa)
    return math.max(work - compressor_work * COMPRESSOR_STATOR_INTERACTION - turbine_work, 0)
end

-- `rpm` off the work and the three parts' efficiencies, rounded up and
-- held under the parts' rating (turbine.dm:681-682).
function gas_turbine_stages.rpm(
    work: number,
    compressor: number,
    rotor: number,
    stator: number,
    max_rpm: number
): number
    local rpm = math.pow(work * compressor, stator) * rotor / RPM_CONVERSION
    return math.min(math.ceil(rpm), max_rpm)
end

-- The grid's watts at `rpm`: tg adds `rpm * 0.3 * 15 * seconds_per_tick`
-- joules a pass (turbine.dm:684), so this a second.
function gas_turbine_stages.watts(rpm: number): number
    return rpm * RECTIFICATION * RPM_CONVERSION
end

return gas_turbine_stages
