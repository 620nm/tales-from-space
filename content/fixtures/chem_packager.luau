-- What the chem packager DOES, as opposed to what it IS
-- (machines/chem_packager.luau).
--
-- One operation: dock a vessel, press `package`, and the machine prints
-- five pills onto its own tray, each carrying a fifth of what was in
-- the vessel. tg's ChemMaster splits its buffer the same way --
-- `volume_in_each = min(round(reagents.total_volume / item_count), ...)`
-- computed once and then N containers filled on a timer
-- (chem_master.dm:514,552-580, `printing_speed = 0.75 SECONDS`).
--
-- THE BUTTON IS THE INTERFACE. `ui.actions` on the machine's file
-- declares it and `interaction.act` delivers the press (docs/TGUI.md,
-- "Content declaration"), so the count is the only thing tg asks for
-- that this machine still does not: five is this file's choice rather
-- than tg's, because tg has no default at all -- `itemCount` is typed
-- and only its CEILING is a constant (`MAX_CONTAINER_PRINT_AMOUNT 50`,
-- chem_master.dm:1). Five is one full beaker's worth of doses at the
-- pack's own numbers and it divides evenly. A typed count wants a
-- setpoint whose ends are native state, which is a machine knob and not
-- a button.
--
-- WHY THE VESSEL GOES IN. The dispenser and the reaction chamber take
-- one into a `HolderSlot` because both work over TIME; this one takes
-- it for the plainer reason tg does -- a print is four seconds long and
-- the machine, not the chemist's arm, is what holds the source steady.
-- The dock is also what makes the pour reachable: a vessel standing in
-- a machine is in reach of whoever can reach the machine (sim/owner.rs).
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

    script_definition:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        if ev.action ~= "package" then
            return { replaced = false }
        end
        local self, user, vessel = ev.subject, ev.actor, ev.docked
        if vessel == nil then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.chem_packager.there_is_nothing_in_the", {}),
            })
            return true
        end
        local held = condensed(vessel)
        if held == nil then
            return { replaced = false } -- not something that holds anything
        end
        if not sim.is_powered(self) then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.chem_packager.the_packager_is_dark_and", {}),
            })
            return true
        end
        if held < 1e-9 then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.chem_packager.there_is_nothing_in_it", {}),
            })
            return true
        end
        -- tg computes the per-container dose ONCE, off the buffer as it
        -- stood when the print was ordered (chem_master.dm:514).
        local share = held / PILLS
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:fixtures.chem_packager.the_extruder_starts_printing", {}),
        })
        sim.spawn_task(user, function()
            for _ = 1, PILLS do
                sim.entity.spawn({ definition = "pill", at = self.tile })
                -- tg's `printing_speed = 0.75 SECONDS`
                -- (chem_master.dm:32).
                if sim.do_after(user, sim.ticks(0.75), {}) == "interrupted" then
                    sim.message.send({
                        recipient = user,
                        message = sim.msg("lunatic/tfs:fixtures.chem_packager.the_extruder_stops", {}),
                    })
                    return true
                end
                if not sim.is_powered(self) then
                    sim.message.send({
                        recipient = user,
                        message = sim.msg("lunatic/tfs:fixtures.chem_packager.the_packager_goes_dark", {}),
                    })
                    return true
                end
                local blank = blank_at(self.tile)
                if blank == nil then
                    return true
                end
                sim.matter.pour({ from = vessel, to = blank, amount = share })
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/vend", at = self.tile })
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.chem_packager.the_extruder_clicks_and_stops", {}),
            })
            return true
        end)
        return true
    end)
end

return content
