-- Nonlinear UF6 neutron reflection heating loop and examine status for
-- the Layer-3 East/West reflection chamber (structures/process/reflection_chamber.luau).
local reflection_chamber = {}

local PASS_SECONDS = 0.1
local MIN_UF6_MOL = 0.01
local LINEAR_W_PER_MOL = 150.0
local QUAD_W_PER_MOL2 = 25.0
local CRITICAL_K = 600.0
local OVERHEATED_K = 1100.0
local SUPERCRITICAL_K = 1800.0
local WATCH_VAR = "reflection_watching"

reflection_chamber.PASS_SECONDS = PASS_SECONDS
reflection_chamber.MIN_UF6_MOL = MIN_UF6_MOL
reflection_chamber.LINEAR_W_PER_MOL = LINEAR_W_PER_MOL
reflection_chamber.QUAD_W_PER_MOL2 = QUAD_W_PER_MOL2
reflection_chamber.CRITICAL_K = CRITICAL_K
reflection_chamber.OVERHEATED_K = OVERHEATED_K
reflection_chamber.SUPERCRITICAL_K = SUPERCRITICAL_K
reflection_chamber.WATCH_VAR = WATCH_VAR

local STATUS_BY_STATE: { [string]: string } = {
    standby = "lunatic/tfs:lib.reflection_chamber.status_standby",
    subcritical = "lunatic/tfs:lib.reflection_chamber.status_subcritical",
    critical = "lunatic/tfs:lib.reflection_chamber.status_critical",
    overheated = "lunatic/tfs:lib.reflection_chamber.status_overheated",
    supercritical = "lunatic/tfs:lib.reflection_chamber.status_supercritical",
    open = "lunatic/tfs:lib.reflection_chamber.status_open",
    broken = "lunatic/tfs:lib.reflection_chamber.status_broken",
}

local MESSAGE_KEYS: { string } = {
    "lunatic/tfs:lib.reflection_chamber.status_standby",
    "lunatic/tfs:lib.reflection_chamber.status_subcritical",
    "lunatic/tfs:lib.reflection_chamber.status_critical",
    "lunatic/tfs:lib.reflection_chamber.status_overheated",
    "lunatic/tfs:lib.reflection_chamber.status_supercritical",
    "lunatic/tfs:lib.reflection_chamber.status_open",
    "lunatic/tfs:lib.reflection_chamber.status_broken",
}

function reflection_chamber.message_keys(): { string }
    return MESSAGE_KEYS
end

local function uf6_moles(reading: MatterRead): number
    local u = reading.contents["uf6"]
    if u == nil then
        return 0
    end
    return (u.gas or 0) + (u.liquid or 0) + (u.solid or 0)
end

local function state_for_temperature(temp_k: number): string
    if temp_k >= SUPERCRITICAL_K then
        return "supercritical"
    elseif temp_k >= OVERHEATED_K then
        return "overheated"
    elseif temp_k >= CRITICAL_K then
        return "critical"
    end
    return "subcritical"
end

local function step_chamber(chamber: Handle, add_heat: boolean): boolean
    if not chamber.alive then
        return false
    end
    local state = chamber.state
    if state == "broken" then
        sim.script_var.set({ scope = chamber, key = WATCH_VAR, value = false })
        return false
    end
    if state == "open" then
        return true
    end
    local reading = sim.matter_read(chamber)
    if reading ~= nil then
        local n_uf6 = uf6_moles(reading)
        local next_state = "standby"
        if n_uf6 >= MIN_UF6_MOL then
            if add_heat then
                local watts = QUAD_W_PER_MOL2 * n_uf6 * n_uf6 + LINEAR_W_PER_MOL * n_uf6
                sim.matter.add_energy({ owner = chamber, joules = watts * PASS_SECONDS })
            end
            next_state = state_for_temperature(reading.temp_k)
        end
        if chamber.state ~= next_state then
            sim.appearance.set_state({ entity = chamber, state = next_state })
        end
    end
    return true
end

function reflection_chamber.ensure_watch(chamber: Handle): ()
    if
        not chamber.alive
        or chamber.prototype ~= "reflection_chamber"
        or sim.var(chamber, WATCH_VAR) == true
    then
        return
    end
    sim.script_var.set({ scope = chamber, key = WATCH_VAR, value = true })
    sim.spawn_task(chamber, function()
        sim.sleep(1)
        if not step_chamber(chamber, false) then
            return
        end
        local pass_ticks = math.max(1, sim.ticks(PASS_SECONDS))
        while chamber.alive do
            sim.sleep(pass_ticks)
            if not step_chamber(chamber, true) then
                return
            end
        end
    end)
end

function reflection_chamber.on_initialize(ev: EntityInitializeDonePayload): ()
    reflection_chamber.ensure_watch(ev.entity)
end

function reflection_chamber.on_changed(ev: StructureChangedPayload): ()
    reflection_chamber.ensure_watch(ev.structure)
end

function reflection_chamber.examine_lines(ev: ExamineLinesPayload): { lines: { ExamineLineRow } }
    local lines = table.clone(ev.lines)
    local key = STATUS_BY_STATE[ev.subject.state or "standby"]
    if key ~= nil then
        table.insert(lines, { key = key, message = sim.msg(key, {}) })
    end
    return { lines = lines }
end

return reflection_chamber
