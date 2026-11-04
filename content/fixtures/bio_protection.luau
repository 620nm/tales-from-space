local airborne = require("@lib/medical/airborne")

local ITEM_ID = "lunatic/tfs:bio_protection_probe"
local BIO_PROTECTION_VAR = "lunatic/tfs:biology.bio_protection"

local content = { id = "bio_protection_probe" }

if sim ~= nil then
    local item = sim.define("item", ITEM_ID, {
        visual_layer = "item",
        name = "bio protection probe",
        sprite = "breath_mask",
    })
    item:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local actor = ev.actor
        assert(airborne.bio_protection(actor) == 50, "worn breath mask supplies BIO 50")
        assert(actor.vars[BIO_PROTECTION_VAR] == nil, "protection stays on its worn item")
        assert(airborne.body_source_is_blocked(actor), "the actual masked body cannot emit")
        assert(airborne.source_is_blocked(true, false), "a mask blocks source emission")
        assert(airborne.source_is_blocked(false, true), "internals block source emission")
        assert(not airborne.source_is_blocked(false, false), "an unmasked source without internals emits")

        local synthetic_inventory = {
            {
                item = { vars = { [BIO_PROTECTION_VAR] = 40 } },
                location = { kind = "worn", equipment_slot = "head" },
            },
            {
                item = { vars = { [BIO_PROTECTION_VAR] = 50 } },
                location = { kind = "worn", equipment_slot = "mask" },
            },
            {
                item = { vars = { [BIO_PROTECTION_VAR] = 95 } },
                location = { kind = "worn", equipment_slot = "suit" },
            },
            {
                item = { vars = { [BIO_PROTECTION_VAR] = 100 } },
                location = { kind = "hand" },
            },
        }
        assert(
            airborne.bio_protection_from_inventory(synthetic_inventory :: any) == 90,
            "BIO sums worn head and mask only"
        )

        local nearby_internals_user = false
        for _, candidate in ipairs(sim.query.range(actor.tile, 3, {})) do
            if candidate ~= actor and sim.body.read(candidate) ~= nil then
                if airborne.uses_internals(candidate) then
                    assert(airborne.body_source_is_blocked(candidate), "the active internals body cannot emit")
                    nearby_internals_user = true
                end
            end
        end
        assert(nearby_internals_user, "a nearby carried tank has an accepted active-supply receipt")

        local function no_roll(_stage: "internals" | "bio"): number
            error("zero protection must not roll")
        end
        assert(
            airborne.protection_allows_catch(0, false, no_roll),
            "unmasked targets always pass the protection gates"
        )
        assert(not airborne.protection_allows_catch(50, false, function(_stage)
            return 0.49
        end), "BIO 50 blocks below one half")
        assert(airborne.protection_allows_catch(50, false, function(_stage)
            return 0.5
        end), "BIO 50 allows one half")
        assert(not airborne.protection_allows_catch(90, false, function(_stage)
            return 0.899
        end), "BIO 90 blocks below nine tenths")
        assert(airborne.protection_allows_catch(90, false, function(_stage)
            return 0.9
        end), "BIO 90 allows nine tenths")
        assert(not airborne.protection_allows_catch(0, true, function(stage)
            assert(stage == "internals", "internals is the first catch gate")
            return 0.749
        end), "active internals block three quarters of catches")

        local stages = ""
        assert(airborne.protection_allows_catch(50, true, function(stage)
            stages ..= stage .. ","
            return if stage == "internals" then 0.75 else 0.5
        end), "BIO runs after an internals pass")
        assert(stages == "internals,bio,", "catch gates preserve tg short-circuit order")

        sim.message.send({
            recipient = actor,
            message = sim.msg("lunatic/tfs:fixtures.bio_protection.checks_passed", {}),
        })
        return true
    end)
end

return content
