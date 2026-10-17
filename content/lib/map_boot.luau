-- WHEN A ROUND STARTS, in one place.
--
-- A server run without `--playtest` installs no map: every round publishes
-- `round.bootstrap` once, before any install, and this pack answers it
-- (the engine's `docs/rounds/lifecycle.md`). The map the host was started
-- with arrives as `host_map`, its stem. The pack ships no root `maps/`
-- directory, so a server started without one has nothing to instantiate:
-- it says so in the ledger and no round begins.
--
-- Both modes bind the two handlers below with `map_boot.install`.

local map_boot = {}

-- Ledger kind declared in content/ledger.luau.
local FAILED = "lunatic/tfs:map_boot_failed"
local PREFIX = "lunatic/tfs:"

type SeamRoute = {
    target_map: string,
    landing_tag: string,
}

local SEAM_ROUTES: { [string]: SeamRoute } = {
    seam_east = {
        target_map = "seam_east",
        landing_tag = "seam_landing_west",
    },
    seam_west = {
        target_map = "seam_west",
        landing_tag = "seam_landing_east",
    },
}

local function landing_has_tag(at: TileAddress, wanted_tag: string): boolean
    for _, tag in ipairs(sim.area_tags(at)) do
        if tag == wanted_tag then
            return true
        end
    end
    return false
end

type LandingCoordinate = { x: number, y: number, z: number }

-- The first landing per (map selector, tag), kept as coordinates. A remembered
-- tile is re-minted on use and kept only while it still carries the tag, so a
-- map that changed underneath falls back to a fresh scan.
local landing_memo: { [string]: { [string]: LandingCoordinate } } = {}

local function remembered_landing(map_selector: string, wanted_tag: string): TileAddress?
    local per_tag = landing_memo[map_selector]
    local coordinate = per_tag and per_tag[wanted_tag]
    if coordinate == nil then
        return nil
    end
    local ok, at = pcall(sim.map_tile, map_selector, coordinate.x, coordinate.y, coordinate.z)
    if ok and at ~= nil and landing_has_tag(at, wanted_tag) then
        return at
    end
    return nil
end

local function find_seam_landing(map_selector: string, wanted_tag: string): TileAddress?
    local known = remembered_landing(map_selector, wanted_tag)
    if known ~= nil then
        return known
    end
    local ok_ext, extent = pcall(sim.map_extent, map_selector)
    if not ok_ext then
        return nil
    end
    for z = 0, extent.depth - 1 do
        for y = 0, extent.height - 1 do
            for x = 0, extent.width - 1 do
                local at = sim.map_tile(map_selector, x, y, z)
                if at ~= nil and landing_has_tag(at, wanted_tag) then
                    local per_tag = landing_memo[map_selector]
                    if per_tag == nil then
                        per_tag = {}
                        landing_memo[map_selector] = per_tag
                    end
                    per_tag[wanted_tag] = { x = x, y = y, z = z }
                    return at
                end
            end
        end
    end
    return nil
end

function map_boot.on_cross_done(ev: MoveCrossDonePayload): ()
    if ev.outcome ~= "completed" then
        return
    end
    local tags = sim.area_tags(ev.to)
    if #tags == 0 then
        return
    end
    for _, tag in ipairs(tags) do
        local route = SEAM_ROUTES[tag]
        if route ~= nil then
            local landing = find_seam_landing(PREFIX .. route.target_map, route.landing_tag)
                or find_seam_landing(route.target_map, route.landing_tag)
            if landing ~= nil then
                sim.entity.transfer({ entity = ev.mover, to = landing })
            end
            return
        end
    end
end

local function record_failure(stage: string, source: string?, reason: string?)
    sim.ledger.record({
        kind = FAILED,
        fields = { stage = stage, source = source, reason = reason },
    })
end

-- The logical id of a host map stem: its tail is lowercased to the engine's
-- resource-tail rule (lowercase, digits, `_`, `.`, `/`, `-`). Nil when the
-- stem cannot be made valid, so the bootstrap refuses with a row.
local function logical_for_stem(stem: string): string?
    local tail = string.lower(stem)
    if string.match(tail, "^[a-z0-9_][a-z0-9_./-]*$") == nil then
        return nil
    end
    return PREFIX .. tail
end

-- Binds both handlers on `behavior`. The engine settles one install at a
-- time, so one pending request is the whole book.
function map_boot.install(behavior: Definition): ()
    local pending: RequestId? = nil

    behavior:handle("round.bootstrap", { kind = "react" }, function(ev: RoundBootstrapPayload)
        local stem = ev.host_map
        if stem == nil then
            record_failure("no_host_map", nil, nil)
            return
        end
        local logical = logical_for_stem(stem)
        if logical == nil then
            record_failure("invalid_logical", stem, "the stem has no valid resource tail")
            return
        end
        pending = sim.maps.instantiate({
            source = stem,
            logical = logical,
        })
    end)

    local function on_instantiated(ev: MapsInstantiateDonePayload)
        local expected = pending
        if expected == nil or expected ~= ev.request then
            return
        end
        pending = nil
        if ev.outcome ~= "completed" then
            record_failure(ev.outcome, ev.source, ev.reason)
            return
        end
        sim.round.begin({ map = ev.logical or ev.source })
    end
    behavior:handle("maps.instantiate.done", { kind = "react" }, on_instantiated)
end

return map_boot
