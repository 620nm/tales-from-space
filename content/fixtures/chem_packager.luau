-- What the chem packager DOES, as opposed to what it IS
-- (machines/chem_packager.luau).
--
-- One operation: hold a vessel against the extruder and it prints five
-- pills onto its own tray, each carrying a fifth of what was in the
-- vessel. tg's ChemMaster splits its buffer the same way --
-- `volume_in_each = min(round(reagents.total_volume / item_count), ...)`
-- computed once and then N containers filled on a timer
-- (chem_master.dm:514,552-580, `printing_speed = 0.75 SECONDS`).
--
-- THE GESTURE IS THE WHOLE INTERFACE, and that is a departure worth
-- stating. tg asks for the count in a window; a window act never
-- reaches content (docs/TGUI.md, "Action boundary" -- the module roster
-- is the engine's and closed), so a scripted machine cannot own a
-- button. What is left is the click, and the click is enough: the
-- vessel you are holding is the buffer, five is the count, and standing
-- still for the print is the confirmation. Five is this file's choice
-- rather than tg's, because tg has no default at all -- `itemCount` is
-- typed and only its CEILING is a constant (`MAX_CONTAINER_PRINT_AMOUNT
-- 50`, chem_master.dm:1). Five is one full beaker's worth of doses at
-- the pack's own numbers and it divides evenly.
--
-- AND WHY IT IS A CLICK RATHER THAN A DOCK. The chem dispenser and the
-- reaction chamber take a vessel into a `HolderSlot` because both of
-- them work over TIME and want the vessel still there when the chemist
-- has wandered off. Packaging begins and ends inside one gesture, so
-- the beaker never leaves the hand -- which also means the engine's
-- do_after guard, which already watches that hand, is the whole of the
-- interruption rule.
--
-- HOW A PILL GETS ITS DOSE. `sim.entity.spawn` is an EFFECT: it is
-- buffered and applied when the segment commits, so there is no handle
-- to fill in the same breath (docs/LUAU-API.md 6 and 8). The loop
-- therefore extrudes a blank, waits out one pill's print time -- which
-- is the transaction boundary that makes the blank real -- and then
-- fills the one blank standing on its tray. A pill that has been filled
-- is no longer blank, so the next pass finds only the next one; a blank
-- somebody LEFT on the tray gets filled too, which is what a tray is
-- for.
local PILLS = 5

local content = {
    id = "chem_packager",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- Everything that is actually IN a vessel, condensed phases only:
    -- what a pill can carry is a liquid or a powder, and a vapour over
    -- it belongs to the beaker.
    local function condensed(obj)
        local read = sim.matter_read(obj)
        if read == nil then
            return nil
        end
        local n = 0
        for _, phases in pairs(read.contents) do
            n = n + (phases.liquid or 0) + (phases.solid or 0)
        end
        return n
    end

    -- The one blank on the tray, or nil. A pill that already holds
    -- something is somebody's dose and is never topped up.
    local function blank_at(tile)
        for _, pill in ipairs(sim.query.range(tile, 0, { prototype = "pill" })) do
            local read = sim.matter_read(pill)
            if read ~= nil and read.moles < 1e-9 then
                return pill
            end
        end
        return nil
    end

    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _target, _victim, _info = target, victim, info
        local vessel = item
        if vessel == nil then
            return { replaced = false }
        end
        local held = condensed(vessel)
        if held == nil then
            return { replaced = false } -- not something that holds anything
        end
        if not sim.is_powered(self) then
            sim.message.send({ recipient = user, message = "The packager is dark and silent." })
            return true
        end
        if held < 1e-9 then
            sim.message.send({ recipient = user, message = "There is nothing in it to package." })
            return true
        end
        -- tg computes the per-container dose ONCE, off the buffer as it
        -- stood when the print was ordered (chem_master.dm:514).
        local share = held / PILLS
        sim.message.send({ recipient = user, message = "You hold it against the extruder." })
        sim.spawn_task(user, function()
            for _ = 1, PILLS do
                sim.entity.spawn({ definition = "pill", at = self.tile })
                -- tg's `printing_speed = 0.75 SECONDS`
                -- (chem_master.dm:32).
                if sim.do_after(user, sim.ticks(0.75), {}) == "interrupted" then
                    sim.message.send({ recipient = user, message = "The extruder stops." })
                    return true
                end
                if not sim.is_powered(self) then
                    sim.message.send({ recipient = user, message = "The packager goes dark." })
                    return true
                end
                local blank = blank_at(self.tile)
                if blank == nil then
                    return true
                end
                sim.matter.pour({ from = vessel, to = blank, amount = share })
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/vend", at = self.tile })
            sim.message.send({ recipient = user, message = "The extruder clicks and stops." })
            return true
        end)
        return true
    end)
end

return content
