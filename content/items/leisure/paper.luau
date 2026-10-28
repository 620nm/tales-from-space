local paper_plane = require("@lib/paper_plane")
local physical_profiles = require("@lib/physical_profiles")
local writing = require("@lib/writing")

-- A single writable sheet. The file store is the paper's authoritative
-- body; fragments preserve each writing gesture's presentation.
-- tg paper.dm:13-31 and :182-190. Folded, the same sheet is a plane
-- (tg paper.dm:393-416, paperplane.dm:4-6); `lib/paper_plane.luau` owns
-- what it does over a hole. It stays the same file store, so it keeps its writing.
local content = {
    id = "paper",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.paper.name",
    name = "paper",
    sprite = "paper",
    inhand_sprite = { "held_paper_l", "held_paper_r" },
    hint_tags = { "paper" },
    states = { paper_plane.FLAT_STATE, paper_plane.FOLDED_STATE, paper_plane.ONFIRE_STATE },
    state = paper_plane.FLAT_STATE,
    state_sprites = {
        [paper_plane.FOLDED_STATE] = "paperplane",
        [paper_plane.ONFIRE_STATE] = "paperplane_onfire",
    },
    -- tg folds on alt-click (paper.dm:393-397).
    gestures = { "alt_primary" },
    files = {
        -- Body bytes and frozen per-fragment style metadata share the store
        -- budget; leave room for the full 8 KiB body plus 64 style records.
        capacity = 32768,
        files = 1,
        append_only = true,
        seed = { { name = "paper1", ext = "md", body = "" } },
    },
    -- Verbatim body from tg code/modules/paperwork/paper_premade.dm:285-443.
    variants = {
        blood_types = {
            name = "blood type compatibility reference",
            name_label = "lunatic/tfs:entity.paper.blood_types.name",
            files = {
                seed = { { reference = "blood_type_compatibility" } },
            },
        },
    },
}

content.actions = {
    {
        id = "fold",
        gesture = "alt_primary",
        route = "self_use",
        label = "lunatic/tfs:action.paper.fold",
        target = { fact = "target.state", value = paper_plane.FLAT_STATE },
    },
    {
        id = "unfold",
        gesture = "self",
        route = "self_use",
        label = "lunatic/tfs:action.paper.unfold",
        target = { fact = "target.state", value = paper_plane.FOLDED_STATE },
    },
}

local function tell(actor: Handle, key: string): ()
    sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
end

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:paper", { prototype = content.id })
    sim.define("script_var", "lunatic/tfs:" .. paper_plane.HEADING_X_VAR, { replicate = "server" })
    sim.define("script_var", "lunatic/tfs:" .. paper_plane.HEADING_Y_VAR, { replicate = "server" })

    -- The append is an effect, so refresh only after native admission. A
    -- failed append leaves the browser's draft intact and reports refusal.
    sim.handle("documents.append.done", { kind = "react" }, function(ev)
        local paper = ev.target
        if paper == nil or (paper.base or paper.prototype) ~= content.id or ev.actor == nil then
            return
        end
        if ev.outcome == "completed" then
            writing.update(ev.actor, paper, "")
        else
            sim.message.send({
                recipient = ev.actor,
                message = sim.msg("lunatic/tfs:items.writing.failed", {}),
            })
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
        if ev.channel ~= "writing" then
            return { replaced = false }
        end
        local value = ev.value or ""
        if ev.action ~= "write" or value == "" then
            return true
        end
        -- tg refuses a pen on a plane (paperplane.dm:84-86).
        if ev.subject.state ~= paper_plane.FLAT_STATE then
            tell(ev.actor, "lunatic/tfs:items.paper.unfold_first")
            return true
        end

        -- `implement` is the exact proposed/contact-bound held tool. Native
        -- admission freezes its style and Mind and consumes a charge only
        -- after the append succeeds.
        writing.append(ev.subject, ev.implement, value)
        return true
    end)

    -- Alt-click folds a flat sheet; using a plane unfolds it
    -- (tg paper.dm:393-397, paperplane.dm:71-81). A burning plane does neither.
    behavior:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local paper = ev.subject
        if ev.gesture == "alt_primary" and paper.state == paper_plane.FLAT_STATE then
            sim.appearance.set_state({ entity = paper, state = paper_plane.FOLDED_STATE })
            tell(ev.actor, "lunatic/tfs:items.paper.folded")
            return true
        elseif ev.gesture == "primary" and paper.state == paper_plane.FOLDED_STATE then
            sim.appearance.set_state({ entity = paper, state = paper_plane.FLAT_STATE })
            tell(ev.actor, "lunatic/tfs:items.paper.unfolded")
            return true
        end
        return { replaced = false }
    end)

    behavior:handle("item.fall.done", { kind = "react", route = "land" }, paper_plane.on_fall_done)
end

return content
