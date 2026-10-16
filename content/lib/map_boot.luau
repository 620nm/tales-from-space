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

local function record_failure(stage: string, source: string?, reason: string?)
    sim.ledger.record({
        kind = FAILED,
        fields = { stage = stage, source = source, reason = reason },
    })
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
        pending = sim.maps.instantiate({
            source = stem,
            logical = "lunatic/tfs:" .. stem,
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
