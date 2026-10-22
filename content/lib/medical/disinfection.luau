local disinfection = {}
local illnesses = require("@lib/medical/illnesses")

type Threshold = { agent: string, fraction: number }
type InactivationConfig = {
    valid: boolean,
    contact_seconds: number,
    thresholds: { Threshold },
}
type ContactClock = { since_tick: number, last_tick: number }
type RegistryEntry = {
    key: string,
    page_id: number,
    holder: Handle?,
    clocks: { [number]: ContactClock },
    confirmed: boolean,
    initial_missing_sweeps: number,
    retired: boolean,
}
type RegistryPage = {
    id: number,
    previous_id: number,
    next_id: number,
    entries: { RegistryEntry },
}
type RetiredEntry = { entry: RegistryEntry, clocks: { [number]: ContactClock } }
type LiquidSample = { amount_by_name: { [string]: number }, total_ml: number }
type RiderRow = { id: string, fields: { [any]: any }, pending: boolean? }
type RiderStatus = "missing" | "pending" | "invalid" | "ready"

local PAGE_CAPACITY = 32
local DISPATCH_PAGE_LIMIT = 16
local CHUNK_EVENT = "lunatic/tfs:disinfection.chunk"

local DEFAULT_ORDER: { string } = {
    "chlorine",
    "bromine",
    "fluorine",
    "iodine",
    "ethanol",
    "space_cleaner",
    "phenol",
}
local DEFAULT_FRACTIONS: { [string]: number } = {
    chlorine = 0.001,
    bromine = 0.001,
    fluorine = 0.001,
    iodine = 0.01,
    ethanol = 0.70,
    space_cleaner = 0.10,
    phenol = 0.05,
}
local configs: { [number]: InactivationConfig } = {}
local registry_pages: { [number]: RegistryPage } = {}
local by_holder: { [string]: RegistryEntry } = {}
local first_page_id = 0
local last_page_id = 0
local dispatch_page_id = 0
local compaction_page_id = 0
local page_count = 0
local next_page_id = 1
local liquid_names: { string } = {}
local liquid_amounts: { [string]: number } = {}
local liquid_sample: LiquidSample = { amount_by_name = liquid_amounts, total_ml = 0 }
local present_indices: { [number]: boolean } = {}

local function finite_number(value: any): boolean
    return typeof(value) == "number" and value == value and value - value == 0
end

local function valid_index(index: any): boolean
    return finite_number(index) and index >= 0 and index % 1 == 0
end

local function normalize_indices(indices: { number }): { number }?
    local found: { [number]: boolean } = {}
    local result: { number } = {}
    for _, index in ipairs(indices) do
        if not valid_index(index) then
            return nil
        end
        if not found[index] then
            found[index] = true
            table.insert(result, index)
        end
    end
    table.sort(result)
    return result
end

local function invalid_config(): InactivationConfig
    return {
        valid = false,
        contact_seconds = 10,
        thresholds = {},
    }
end

local function rule_for(index: number): InactivationConfig?
    local cached = configs[index]
    if cached ~= nil then
        return cached
    end

    local definition = illnesses.get(index)
    if definition == nil then
        return nil
    end

    local override: any = definition.inactivation
    local contact_seconds = 10
    if override ~= nil then
        if typeof(override) ~= "table" then
            local invalid = invalid_config()
            configs[index] = invalid
            return invalid
        end
        local configured_contact: any = override.contact_seconds
        if configured_contact ~= nil then
            if not finite_number(configured_contact) or configured_contact <= 0 then
                local invalid = invalid_config()
                configs[index] = invalid
                return invalid
            end
            contact_seconds = configured_contact
        end
    end

    local fractions: any = nil
    if override ~= nil then
        fractions = override.min_fractions
    end

    local thresholds: { Threshold } = {}
    if fractions == nil then
        for _, agent in ipairs(DEFAULT_ORDER) do
            table.insert(thresholds, {
                agent = agent,
                fraction = DEFAULT_FRACTIONS[agent],
            })
        end
    else
        if typeof(fractions) ~= "table" then
            local invalid = invalid_config()
            configs[index] = invalid
            return invalid
        end
        local agents: { string } = {}
        for agent, fraction in pairs(fractions) do
            if typeof(agent) ~= "string"
                or agent == ""
                or typeof(fraction) ~= "number"
                or not finite_number(fraction)
                or fraction <= 0
                or fraction > 1
            then
                local invalid = invalid_config()
                configs[index] = invalid
                return invalid
            end
            table.insert(agents, agent)
        end
        table.sort(agents)
        for _, agent in ipairs(agents) do
            table.insert(thresholds, {
                agent = agent,
                fraction = fractions[agent],
            })
        end
    end

    local config: InactivationConfig = {
        valid = true,
        contact_seconds = contact_seconds,
        thresholds = thresholds,
    }
    configs[index] = config
    return config
end

local function read_liquid_sample(holder: Handle): LiquidSample?
    for index = #liquid_names, 1, -1 do
        liquid_names[index] = nil
    end
    for name in pairs(liquid_amounts) do
        liquid_amounts[name] = nil
    end
    liquid_sample.total_ml = 0

    local matter = sim.matter_read(holder)
    if matter == nil or typeof(matter.contents) ~= "table" then
        return nil
    end

    for name, phases in pairs(matter.contents) do
        if typeof(name) ~= "string" or typeof(phases) ~= "table" then
            return nil
        end
        table.insert(liquid_names, name)
    end
    table.sort(liquid_names)

    local total_ml = 0
    for _, name in ipairs(liquid_names) do
        local phases = matter.contents[name]
        local liquid_ml: any = phases.liquid_ml
        if liquid_ml == nil then
            liquid_ml = 0
        elseif not finite_number(liquid_ml) or liquid_ml < 0 then
            return nil
        end
        liquid_amounts[name] = liquid_ml
        total_ml += liquid_ml
        if not finite_number(total_ml) then
            return nil
        end
    end
    liquid_sample.total_ml = total_ml
    return liquid_sample
end

local function potency(sample: LiquidSample?, config: InactivationConfig): number?
    if sample == nil or sample.total_ml <= 0 then
        return nil
    end
    local total = 0
    for _, threshold in ipairs(config.thresholds) do
        local agent_ml = sample.amount_by_name[threshold.agent] or 0
        total += (agent_ml / sample.total_ml) / threshold.fraction
        if not finite_number(total) then
            return nil
        end
    end
    return total
end

local function append_entry(entry: RegistryEntry): ()
    local tail = registry_pages[last_page_id]
    if tail ~= nil and #tail.entries < PAGE_CAPACITY then
        local replacement: { RegistryEntry } = {}
        for _, current in ipairs(tail.entries) do
            table.insert(replacement, current)
        end
        table.insert(replacement, entry)
        tail.entries = replacement
        entry.page_id = tail.id
    else
        if last_page_id ~= 0 and tail == nil then
            error("disinfection registry tail page is missing")
        end
        local previous: RegistryPage? = nil
        if last_page_id ~= 0 then
            previous = registry_pages[last_page_id]
            if previous == nil then
                error("disinfection registry tail page is missing")
            end
        end
        local id = next_page_id
        next_page_id += 1
        local created: RegistryPage = {
            id = id,
            previous_id = last_page_id,
            next_id = 0,
            entries = { entry },
        }
        registry_pages[id] = created
        if previous == nil then
            first_page_id = id
        else
            previous.next_id = id
        end
        last_page_id = id
        page_count += 1
        if compaction_page_id == 0 then
            compaction_page_id = id
        end
        entry.page_id = id
    end
    by_holder[entry.key] = entry
end

local function finalize_retirement(retirement: RetiredEntry): ()
    local entry = retirement.entry
    if by_holder[entry.key] == entry then
        by_holder[entry.key] = nil
    end
    entry.retired = true
    entry.holder = nil
    entry.clocks = retirement.clocks
end

local function unlink_empty_page(page: RegistryPage): ()
    if #page.entries ~= 0 then
        return
    end
    local previous_id = page.previous_id
    local next_id = page.next_id
    local previous: RegistryPage? = nil
    local next_page: RegistryPage? = nil
    if previous_id ~= 0 then
        previous = registry_pages[previous_id]
    end
    if next_id ~= 0 then
        next_page = registry_pages[next_id]
    end
    if previous_id ~= 0 and previous == nil then
        error("disinfection registry previous page is missing")
    end
    if next_id ~= 0 and next_page == nil then
        error("disinfection registry next page is missing")
    end
    if previous_id == 0 then
        first_page_id = next_id
    else
        if previous == nil then
            error("disinfection registry previous page is missing")
        end
        previous.next_id = next_id
    end
    if next_id == 0 then
        last_page_id = previous_id
    else
        if next_page == nil then
            error("disinfection registry next page is missing")
        end
        next_page.previous_id = previous_id
    end
    registry_pages[page.id] = nil
    page_count -= 1
    if dispatch_page_id == page.id then
        dispatch_page_id = if next_id ~= 0 then next_id else first_page_id
    end
    if compaction_page_id == page.id then
        compaction_page_id = if next_id ~= 0 then next_id else first_page_id
    end
end

local function compact_one_adjacent_pair(): ()
    if page_count <= DISPATCH_PAGE_LIMIT then
        return
    end
    local left_id = compaction_page_id
    if left_id == 0 or registry_pages[left_id] == nil then
        left_id = first_page_id
    end
    local left = registry_pages[left_id]
    if left == nil then
        compaction_page_id = 0
        return
    end
    if left.next_id == 0 then
        compaction_page_id = first_page_id
        left_id = first_page_id
        left = registry_pages[left_id]
        if left == nil then
            error("disinfection registry first page is missing")
        end
        if left.next_id == 0 then
            return
        end
    end
    local right = registry_pages[left.next_id]
    if right == nil then
        error("disinfection registry compaction page is missing")
    end
    if #left.entries > PAGE_CAPACITY or #right.entries > PAGE_CAPACITY then
        error("disinfection registry page exceeds its capacity")
    end
    for _, entry in ipairs(left.entries) do
        if entry.page_id ~= left.id then
            error("disinfection registry left entry has a stale page id")
        end
    end
    for _, entry in ipairs(right.entries) do
        if entry.page_id ~= right.id then
            error("disinfection registry right entry has a stale page id")
        end
    end

    local capacity = PAGE_CAPACITY - #left.entries
    if capacity <= 0 then
        compaction_page_id = right.id
        return
    end
    local moved_count = math.min(capacity, #right.entries)
    if moved_count == 0 then
        compaction_page_id = right.id
        return
    end

    local replacement_left: { RegistryEntry } = {}
    for _, entry in ipairs(left.entries) do
        table.insert(replacement_left, entry)
    end
    local replacement_right: { RegistryEntry } = {}
    for index, entry in ipairs(right.entries) do
        if index <= moved_count then
            table.insert(replacement_left, entry)
        else
            table.insert(replacement_right, entry)
        end
    end

    left.entries = replacement_left
    right.entries = replacement_right
    for index = #left.entries - moved_count + 1, #left.entries do
        left.entries[index].page_id = left.id
    end
    if #right.entries == 0 then
        compaction_page_id = left.id
        unlink_empty_page(right)
    else
        compaction_page_id = right.id
    end
end

local function retire_one(entry: RegistryEntry): ()
    if entry.retired then
        return
    end
    local page = registry_pages[entry.page_id]
    if page == nil then
        error("disinfection registry entry page is missing")
    end
    local retained: { RegistryEntry } = {}
    local found = false
    for _, current in ipairs(page.entries) do
        if current == entry then
            if found then
                error("disinfection registry entry is duplicated")
            end
            found = true
        else
            table.insert(retained, current)
        end
    end
    if not found then
        error("disinfection registry entry is not in its page")
    end
    local retirement: RetiredEntry = { entry = entry, clocks = {} }
    page.entries = retained
    finalize_retirement(retirement)
    unlink_empty_page(page)
end

local function candidate_for(holder: Handle, key: string): RegistryEntry?
    local candidate = by_holder[key]
    if candidate == nil or candidate.retired then
        return candidate
    end
    local existing_holder = candidate.holder
    if existing_holder == holder then
        return candidate
    end
    if existing_holder ~= nil and existing_holder.alive then
        error("disinfection holder identity key names a different live handle")
    end
    if existing_holder == nil then
        error("disinfection registry has a live entry without its holder")
    end
    retire_one(candidate)
    return nil
end

local function entry_for(holder: Handle): RegistryEntry?
    if not holder.alive then
        return nil
    end
    local key = tostring(holder)
    local entry = candidate_for(holder, key)
    if entry ~= nil then
        if not entry.retired then
            return entry
        end
        if by_holder[key] == entry then
            by_holder[key] = nil
        end
    end

    local created: RegistryEntry = {
        key = key,
        page_id = 0,
        holder = holder,
        clocks = {},
        confirmed = false,
        initial_missing_sweeps = 0,
        retired = false,
    }
    append_entry(created)
    return created
end

local function read_rider(holder: Handle): (RiderStatus, { number }?)
    local rows = sim.riders(holder) :: { RiderRow }?
    if rows == nil then
        return "missing", nil
    end

    local found: RiderRow? = nil
    for _, row in ipairs(rows) do
        if row.id == "contagion" then
            if found ~= nil then
                return "invalid", nil
            end
            found = row
        end
    end
    if found == nil then
        return "missing", nil
    end
    if found.pending == true then
        return "pending", nil
    end

    local raw: any = found.fields.illnesses
    if typeof(raw) ~= "table" then
        return "invalid", nil
    end
    local indices: { number } = {}
    for key, index in pairs(raw) do
        if typeof(key) ~= "number"
            or key < 1
            or key % 1 ~= 0
            or typeof(index) ~= "number"
            or not valid_index(index)
        then
            return "invalid", nil
        end
        table.insert(indices, index)
    end
    if #raw ~= #indices then
        return "invalid", nil
    end
    table.sort(indices)
    local write_index = 1
    for read_index = 1, #indices do
        local index = indices[read_index]
        if read_index == 1 or index ~= indices[read_index - 1] then
            indices[write_index] = index
            write_index += 1
        end
    end
    for index = write_index, #indices do
        indices[index] = nil
    end
    return "ready", indices
end

local function reset_clocks(entry: RegistryEntry): ()
    entry.clocks = {}
end

local function prune_clocks(entry: RegistryEntry, indices: { number }): ()
    for index in pairs(present_indices) do
        present_indices[index] = nil
    end
    for _, index in ipairs(indices) do
        present_indices[index] = true
    end
    for index in pairs(entry.clocks) do
        if not present_indices[index] then
            entry.clocks[index] = nil
        end
    end
end

local function observe(
    entry: RegistryEntry,
    indices: { number },
    tick: number,
    sample: LiquidSample?
): { number }
    prune_clocks(entry, indices)

    local cured: { number } = {}
    local one_second_ticks = sim.ticks(1)
    if not finite_number(tick)
        or tick < 0
        or tick % 1 ~= 0
        or not finite_number(one_second_ticks)
        or one_second_ticks < 1
    then
        reset_clocks(entry)
        return cured
    end
    local page_revisit_seconds = (page_count + DISPATCH_PAGE_LIMIT - 1) // DISPATCH_PAGE_LIMIT
    local maximum_sample_gap_ticks = page_revisit_seconds * one_second_ticks + 1

    for _, index in ipairs(indices) do
        local config = rule_for(index)
        local current_potency: number? = nil
        if config ~= nil and config.valid then
            current_potency = potency(sample, config)
        end
        if config == nil or not config.valid or current_potency == nil or current_potency < 1 then
            entry.clocks[index] = nil
        else
            local clock = entry.clocks[index]
            if clock == nil
                or tick < clock.last_tick
                or tick - clock.last_tick > maximum_sample_gap_ticks
            then
                clock = { since_tick = tick, last_tick = tick }
                entry.clocks[index] = clock
            else
                clock.last_tick = tick
            end

            local elapsed_seconds = sim.seconds(tick - clock.since_tick)
            if finite_number(elapsed_seconds) and elapsed_seconds >= config.contact_seconds then
                table.insert(cured, index)
                entry.clocks[index] = nil
            end
        end
    end
    return cured
end

local function apply_cures(
    holder: Handle,
    indices: { number },
    cured: { number }
): ()
    if #cured == 0 or not holder.alive then
        return
    end
    local removed: { [number]: boolean } = {}
    for _, index in ipairs(cured) do
        removed[index] = true
    end
    local remaining: { number } = {}
    for _, index in ipairs(indices) do
        if not removed[index] then
            table.insert(remaining, index)
        end
    end

    if #remaining == 0 then
        sim.clear_rider(holder, "contagion")
        return
    end

    sim.set_rider(holder, "contagion", { illnesses = remaining })
end

local function sample_entry(
    entry: RegistryEntry,
    holder: Handle,
    indices: { number },
    tick: number
): ()
    local sample = read_liquid_sample(holder)
    local cured = observe(entry, indices, tick, sample)
    apply_cures(holder, indices, cured)
end

function disinfection.arrived(holder: Handle, indices: { number }): ()
    if not holder.alive then
        return
    end
    local normalized = normalize_indices(indices)
    if normalized == nil then
        local existing = candidate_for(holder, tostring(holder))
        if existing ~= nil then
            reset_clocks(existing)
        end
        return
    end
    if #normalized == 0 then
        return
    end
    local entry = entry_for(holder)
    if entry == nil then
        return
    end

    entry.initial_missing_sweeps = 0

    local tick = sim.tick()
    sample_entry(entry, holder, normalized, tick)
end

function disinfection.cleared(holder: Handle): ()
    local entry = candidate_for(holder, tostring(holder))
    if entry ~= nil then
        if not entry.retired then
            retire_one(entry)
        elseif by_holder[entry.key] == entry then
            by_holder[entry.key] = nil
        end
    end
end

function disinfection.on_chunk(ev: { page: number }): ()
    local tick = sim.tick()
    if not valid_index(ev.page) or ev.page == 0 then
        return
    end
    local page = registry_pages[ev.page]
    if page == nil then
        return
    end

    local retained: { RegistryEntry } = {}
    local retirements: { RetiredEntry } = {}
    for _, entry in ipairs(page.entries) do
        if entry.retired then
            error("retired disinfection entry remains in its page")
        end
        if entry.page_id ~= page.id then
            error("disinfection entry has a stale page id")
        end
        local holder = entry.holder
        if holder == nil then
            error("live disinfection entry has no holder")
        elseif not holder.alive then
            table.insert(retirements, { entry = entry, clocks = {} })
        else
            local status, indices = read_rider(holder)
            if status == "ready" then
                if indices == nil then
                    error("ready disinfection rider has no indices")
                elseif #indices == 0 then
                    table.insert(retirements, { entry = entry, clocks = {} })
                else
                    entry.confirmed = true
                    entry.initial_missing_sweeps = 0
                    sample_entry(entry, holder, indices, tick)
                    table.insert(retained, entry)
                end
            elseif status == "missing" then
                if entry.confirmed then
                    table.insert(retirements, { entry = entry, clocks = {} })
                else
                    entry.initial_missing_sweeps += 1
                    if entry.initial_missing_sweeps > 1 then
                        table.insert(retirements, { entry = entry, clocks = {} })
                    else
                        table.insert(retained, entry)
                    end
                end
            else
                if status == "invalid" then
                    reset_clocks(entry)
                end
                table.insert(retained, entry)
            end
        end
    end

    page.entries = retained
    for _, retirement in ipairs(retirements) do
        finalize_retirement(retirement)
    end
    unlink_empty_page(page)
end

function disinfection.on_second(ev: ClockSecondPayload): ()
    if ev.outcome ~= "completed" then
        return
    end

    compact_one_adjacent_pair()
    if page_count == 0 then
        return
    end
    local dispatch_count = math.min(DISPATCH_PAGE_LIMIT, page_count)
    local page_id = dispatch_page_id
    if page_id == 0 or registry_pages[page_id] == nil then
        page_id = first_page_id
    end
    for _ = 1, dispatch_count do
        local page = registry_pages[page_id]
        if page == nil then
            error("disinfection registry dispatch page is missing")
        end
        local next_id = if page.next_id ~= 0 then page.next_id else first_page_id
        dispatch_page_id = next_id
        page_id = next_id
        local emitted, failure = pcall(sim.emit, CHUNK_EVENT, { page = page.id })
        if not emitted then
            local detail = string.sub(tostring(failure), 1, 512)
            print(
                "disinfection sim.emit failed for event "
                    .. CHUNK_EVENT
                    .. " on page "
                    .. tostring(page.id)
                    .. ": "
                    .. detail
            )
        end
    end
end

return disinfection
