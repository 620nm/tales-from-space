-- A single writable sheet. The file store is the paper's authoritative
-- body; fragments preserve each writing gesture's presentation.
-- tg paper.dm:13-31 and :182-190.
local content = {
    id = "paper",
    name_label = "lunatic/tfs:entity.paper.name",
    name = "paper",
    sprite = "paper",
    inhand_sprite = { "held_paper_l", "held_paper_r" },
    hint_tags = { "paper" },
    files = {
        -- Body bytes and frozen per-fragment style metadata share the store
        -- budget; leave room for the full 8 KiB body plus 64 style records.
        capacity = 32768,
        files = 1,
        append_only = true,
        seed = { { name = "paper1", ext = "md", body = "" } },
    },
}

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:paper", { prototype = content.id })

    -- The append is an effect, so refresh only after native admission. A
    -- failed append leaves the browser's draft intact and reports refusal.
    sim.handle("documents.append.done", { kind = "react" }, function(ev)
        local paper = ev.target
        if paper == nil or paper.prototype ~= content.id or ev.actor == nil then return end
        if ev.outcome == "completed" then
            writing.update(ev.actor, paper, "")
        else
            sim.message.send({ recipient = ev.actor, message = sim.msg("lunatic/tfs:items.writing.failed", {}) })
        end
    end)

    -- A sheet opens its own possession-bound writing document whenever it is
    -- directly held. The native writer context closes stale actions when the
    -- active tool or the paper changes.
    behavior:handle("inventory.present", { kind = "react" }, function(ev)
        if ev.initial or ev.implement ~= nil then
            -- Inventory presentation carries the native held-writer proof.
            -- Reopen when a writer arrives beside an already-held sheet so
            -- the write action is enabled without accepting a client handle.
            writing.open(ev.actor, ev.subject, "", ev.implement)
        end
    end)

    behavior:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        if ev.channel ~= "writing" then return { replaced = false } end
        local value = ev.value or ""
        if ev.action ~= "write" or value == "" then return true end

        -- `implement` is the exact proposed/contact-bound held tool. Native
        -- admission freezes its style and Mind and consumes a charge only
        -- after the append succeeds.
        writing.append(ev.subject, ev.implement, value)
        return true
    end)
end

return content
