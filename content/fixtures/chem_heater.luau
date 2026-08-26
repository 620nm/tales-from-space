-- What the reaction chamber's SOCKET is worth, which is the one thing
-- about this machine that is a judgement rather than an arithmetic
-- (machines/chem_heater.luau).
--
-- The prototype declares an environment modifier: a chamber loses a
-- fifth of a percent of itself per kelvin the room stands away from
-- twenty degrees. That is data and the engine applies it once a tick.
-- What is NOT data is WHEN a machine stops paying it, because that is a
-- claim about parts: a laser good enough to run a chamber at twice its
-- plain rate is a laser with its own housing and its own cooling, and a
-- chamber built around one does not care what the corridor is doing.
--
-- `parts.refresh` is the anchor for exactly this: it fires the four
-- times a roster is SETTLED -- a frame finished, a map's machines at
-- boot, a socket swapped, a script asking -- and never per tick, and
-- the handler answers with DATA the engine then does the arithmetic
-- with (docs/LUAU-API.md, `parts.refresh`).
local content = {
    id = "chem_heater",
}

-- Rung three of the pack's ladder (lib/stock_parts.luau), which is
-- where a laser is worth double the plain part. Two and up is where
-- tg's own better stock parts stop being "the same thing, slightly
-- more" and start being a different housing, and doubling is the
-- honest line to draw the immunity at here.
local SHIELDED_TIER = 3

-- Is every laser in this roster good enough to shield the element? A
-- chamber with no laser socket at all is not shielded -- there is
-- nothing in it doing the shielding -- which is what `found` is for.
local function shielded(slots)
    local found = false
    for _, slot in ipairs(slots) do
        if slot.kind == "laser" then
            found = true
            if slot.tier < SHIELDED_TIER then
                return false
            end
        end
    end
    return found
end

if sim ~= nil then
    -- Which way the last refresh went, in one word. The hook itself is
    -- a transform and may not write; this is the fact a panel, an
    -- examine line or an admin reading the shift record wants, and the
    -- `.done` half is the half allowed to keep it.
    sim.define("script_var", "lunatic/tfs:element", { replicate = "server" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- Return what you changed: a transform works on its own copy and
    -- only the table it RETURNS is merged. Nothing here touches
    -- `slot.efficiency` -- the ladder is the parts' own business and
    -- the file's numbers stand -- so the whole answer is whether the
    -- room still gets a vote.
    script_definition:handle("parts.refresh", { kind = "transform", route = "parts" }, function(ev)
        if shielded(ev.slots) then
            ev.environment.temperature = nil
        end
        return { slots = ev.slots, environment = ev.environment }
    end)

    -- The completion carries the subject and not the draft, so the word
    -- is written off `Handle.components` -- what the sockets hold NOW,
    -- which is the settled answer rather than the one being proposed.
    script_definition:handle("parts.refresh.done", { kind = "react", route = "parts" }, function(ev)
        local settled = ev.subject.components or {}
        ev.subject.vars["element"] = if shielded(settled) then "shielded" else "exposed"
    end)
end

return content
