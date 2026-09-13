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

function service.chunks(text)
    local out = {}
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
                if byte < 128 or byte >= 192 then break end
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
