-- Addressed fax service names and bounded payload shapes. A MAC remains a
-- native service address; this module never manufactures an entity handle.
local service = {}

service.print = "fax.print"
service.send = "fax.send"
service.printed = "fax.printed"
service.sent = "fax.sent"
service.failed = "fax.failed"
service.max_chunk = 4096
service.max_payload = 8192
-- A sheet scanned and printed in lockstep lands on both machines together, so
-- a `fax.print` may carry the sim-clock second its sender began transmitting.
-- A peer's stamp is trusted for timing only, and only within a hop's transit:
-- a receiver honours a stamp no older than this and never a future one.
service.max_transit_seconds = 0.25
-- How long a sender waits after its scan for the recipient's verdict before it
-- reports the send failed.
service.max_reply_seconds = 1

-- The sender's stamp for a transmission beginning now, in sim-clock seconds.
function service.stamp(): number
    return sim.seconds(sim.tick())
end

-- The tick `payload.began` names when it is a plausible stamp, else nil and
-- the receiver times the page from its own delivery.
function service.began(payload: unknown): number?
    if type(payload) ~= "table" then
        return nil
    end
    local stamp = (payload :: { [unknown]: unknown }).began
    if type(stamp) ~= "number" then
        return nil
    end
    local counted, began = pcall(sim.ticks, stamp)
    if not counted then
        return nil
    end
    local now = sim.tick()
    if began > now or now - began > sim.ticks(service.max_transit_seconds) then
        return nil
    end
    return began
end

function service.chunks(text: string): { string }
    local out: { string } = {}
    local at = 1
    while at <= #text do
        local finish = math.min(#text, at + service.max_chunk - 1)
        if finish < #text then
            local original = finish
            -- `string.sub` counts bytes. Retreat over continuation bytes,
            -- then exclude a leading byte whose codepoint would finish past
            -- the bound; this keeps every chunk valid UTF-8.
            local candidate = finish
            while candidate >= at do
                local byte = string.byte(text, candidate)
                if byte < 128 or byte >= 192 then
                    break
                end
                candidate -= 1
            end
            local lead = string.byte(text, candidate)
            local width = 1
            if lead >= 194 and lead <= 223 then
                width = 2
            elseif lead >= 224 and lead <= 239 then
                width = 3
            elseif lead >= 240 and lead <= 244 then
                width = 4
            end
            finish = if candidate + width - 1 > original then candidate - 1 else original
        end
        table.insert(out, string.sub(text, at, finish))
        at = finish + 1
    end
    return out
end

return service
