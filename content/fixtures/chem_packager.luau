-- Bounded packaging operations; docs/CHEMISTRY.md and PETROCHEMISTRY.md.
-- Pills split a docked solution into five doses; solid products extract
-- measured, phase-pure batches while leaving liquid carriers behind.
-- Pill timing follows tg chemistry/machinery/chem_master.dm:32,514,552-580.
local PILLS = 5
local RESIN_PELLET_MOL = 0.1
local PLASTIC_SHEET_MOL = 0.1
local TONER_BATCH_MOL = 0.025
local DREGS_MOL = 1e-9

type ProductRequest = {
    amount: number,
    substance: string,
    definition: string,
    message: string,
    contents: { FillRow }?,
}

local content = {
    id = "chem_packager",
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- Everything that is actually IN a vessel, condensed phases only:
    -- what a pill can carry is a liquid or a powder, and a vapour over
    -- it belongs to the beaker.
    local function condensed(obj: Handle): number?
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
    local function blank_at(tile: TileAddress): Handle?
        for _, pill in ipairs(sim.query.range(tile, 0, { prototype = "pill" })) do
            local read = sim.matter_read(pill)
            if read ~= nil and read.moles < 1e-9 then
                return pill
            end
        end
        return nil
    end

    -- Product buttons only consume the requested solid. Liquid catalyst or
    -- water may remain in the docked vessel, but another solid makes the
    -- batch contaminated and refuses the operation.
    local function pure_solid(read: MatterRead, substance: string, amount: number): boolean
        local wanted = read.contents[substance]
        if wanted == nil or (wanted.solid or 0) + DREGS_MOL < amount then
            return false
        end
        for id, phases in pairs(read.contents) do
            if id ~= substance and (phases.solid or 0) > DREGS_MOL then
                return false
            end
        end
        return true
    end

    local function product_request(action: string): ProductRequest?
        if action == "make_resin_pellet" then
            return {
                amount = RESIN_PELLET_MOL,
                substance = "polymer_resin",
                definition = "resin_pellet",
                message = "lunatic/tfs:fixtures.chem_packager.the_resin_pellet_drops",
                contents = { { substance = "polymer_resin", mol = RESIN_PELLET_MOL } },
            }
        end
        if action == "mold_plastic_sheet" then
            return {
                amount = PLASTIC_SHEET_MOL,
                substance = "polymer_resin",
                definition = "plastic_sheet",
                message = "lunatic/tfs:fixtures.chem_packager.the_plastic_sheet_drops",
                contents = nil,
            }
        end
        if action == "make_toner_cartridge" then
            return {
                amount = TONER_BATCH_MOL,
                substance = "toner",
                definition = "toner_cartridge",
                message = "lunatic/tfs:fixtures.chem_packager.the_toner_cartridge_drops",
                contents = nil,
            }
        end
        return nil
    end

    local function make_product(
        self: Handle,
        user: Handle,
        vessel: Handle,
        request: ProductRequest
    ): boolean
        if not sim.is_powered(self) then
            sim.message.send({
                recipient = user,
                message = sim.msg(
                    "lunatic/tfs:fixtures.chem_packager.the_packager_is_dark_and",
                    {}
                ),
            })
            return true
        end
        local read = sim.matter_read(vessel)
        if read == nil or not pure_solid(read, request.substance, request.amount) then
            sim.message.send({
                recipient = user,
                message = sim.msg(
                    "lunatic/tfs:fixtures.chem_packager.the_batch_is_not_pure_enough",
                    {}
                ),
            })
            return true
        end

        -- Both effects are queued in this one occurrence after the same
        -- reach, power and composition checks. There is no yield that could
        -- leave an extraction without its product or admit a stale source.
        sim.matter.extract({ owner = vessel, amount = request.amount, phases = { "solid" } })
        sim.entity.spawn({
            definition = request.definition,
            at = self.tile,
            initial = if request.contents ~= nil then { contents = request.contents } else nil,
        })
        sim.message.send({ recipient = user, message = sim.msg(request.message, {}) })
        return true
    end

    script_definition:handle("interaction.act", { kind = "replace", route = "act" }, function(ev)
        local product = product_request(ev.action)
        if product ~= nil then
            local vessel = ev.docked
            if vessel == nil then
                sim.message.send({
                    recipient = ev.actor,
                    message = sim.msg("lunatic/tfs:fixtures.chem_packager.there_is_nothing_in_the", {}),
                })
                return true
            end
            return make_product(ev.subject, ev.actor, vessel, product)
        end
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
                message = sim.msg(
                    "lunatic/tfs:fixtures.chem_packager.the_packager_is_dark_and",
                    {}
                ),
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
            message = sim.msg(
                "lunatic/tfs:fixtures.chem_packager.the_extruder_starts_printing",
                {}
            ),
        })
        sim.spawn_task(user, function()
            for _ = 1, PILLS do
                sim.entity.spawn({ definition = "pill", at = self.tile })
                -- tg's `printing_speed = 0.75 SECONDS`
                -- (chem_master.dm:32).
                if sim.do_after(user, sim.ticks(0.75), {}) == "interrupted" then
                    sim.message.send({
                        recipient = user,
                        message = sim.msg(
                            "lunatic/tfs:fixtures.chem_packager.the_extruder_stops",
                            {}
                        ),
                    })
                    return true
                end
                if not sim.is_powered(self) then
                    sim.message.send({
                        recipient = user,
                        message = sim.msg(
                            "lunatic/tfs:fixtures.chem_packager.the_packager_goes_dark",
                            {}
                        ),
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
                message = sim.msg(
                    "lunatic/tfs:fixtures.chem_packager.the_extruder_clicks_and_stops",
                    {}
                ),
            })
            return true
        end)
        return true
    end)
end

return content
