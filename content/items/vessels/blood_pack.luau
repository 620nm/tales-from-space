local blood_identity = require("@lib/blood_identity")
local physical_profiles = require("@lib/physical_profiles")

local content = {
    id = "blood_pack",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    -- tg's base name, description and icon (`code/modules/reagents/reagent_containers/blood_pack.dm:2-5`).
    name_label = "lunatic/tfs:entity.blood_pack.name",
    name = "blood pack",
    sprite = "bloodpack",
    examine = {
        flavor = "Contains blood used for transfusion. Must be attached to an IV drip.",
    },
    -- tg's 200u pack (`code/modules/reagents/reagent_containers/blood_pack.dm:6,13-20`)
    -- is 5mol; at blood's 400g/mol and 1g/mL, that occupies 2,000mL
    -- (`content/substances/blood.luau:6-11,31-34`; engine `docs/chemistry/tg-bridge.md`).
    volume_ml = 2000,
    -- tg leaves the base container flags at NONE
    -- (`code/modules/reagents/reagent_containers.dm:18,73-79`).
    sealed = true,
    -- tg's 10-point ladder (`code/modules/reagents/reagent_containers/blood_pack.dm:7`)
    -- draws its highest eligible band (`code/modules/reagents/reagent_containers.dm:286-306`);
    -- the engine suppresses overlays on empty holders (engine `docs/bench/appearance.md:55-63`).
    fill_sprites = {
        { 0, "bloodpack10" },
        { 20, "bloodpack20" },
        { 30, "bloodpack30" },
        { 40, "bloodpack40" },
        { 50, "bloodpack50" },
        { 60, "bloodpack60" },
        { 70, "bloodpack70" },
        { 80, "bloodpack80" },
        { 90, "bloodpack90" },
        { 100, "bloodpack100" },
    },
    acts_on_items = true,
    script = "blood_pack",
    -- tg adds the type to the label (`code/modules/reagents/reagent_containers/blood_pack.dm:26-29`).
    -- Its 200u dose is 5.0mol at the unit bridge
    -- (`code/modules/reagents/reagent_containers/blood_pack.dm:13-20`; engine `docs/chemistry/tg-bridge.md`).
    variants = {
        -- Order follows `blood_identity.IDS` (`content/lib/blood_identity.luau:16-28`).
        o_minus = {
            name_label = "lunatic/tfs:entity.blood_pack.o_minus.name",
            name = "blood pack - O-",
            contents = { blood = 5.0 },
        },
        o_plus = {
            name_label = "lunatic/tfs:entity.blood_pack.o_plus.name",
            name = "blood pack - O+",
            contents = { blood = 5.0 },
        },
        a_minus = {
            name_label = "lunatic/tfs:entity.blood_pack.a_minus.name",
            name = "blood pack - A-",
            contents = { blood = 5.0 },
        },
        a_plus = {
            name_label = "lunatic/tfs:entity.blood_pack.a_plus.name",
            name = "blood pack - A+",
            contents = { blood = 5.0 },
        },
        b_minus = {
            name_label = "lunatic/tfs:entity.blood_pack.b_minus.name",
            name = "blood pack - B-",
            contents = { blood = 5.0 },
        },
        b_plus = {
            name_label = "lunatic/tfs:entity.blood_pack.b_plus.name",
            name = "blood pack - B+",
            contents = { blood = 5.0 },
        },
        -- The pack covers all eight human blood types; tg defines six fixed
        -- human subtypes (`code/modules/reagents/reagent_containers/blood_pack.dm:39-55`).
        ab_minus = {
            name_label = "lunatic/tfs:entity.blood_pack.ab_minus.name",
            name = "blood pack - AB-",
            contents = { blood = 5.0 },
        },
        ab_plus = {
            name_label = "lunatic/tfs:entity.blood_pack.ab_plus.name",
            name = "blood pack - AB+",
            contents = { blood = 5.0 },
        },
        random = {
            name = "blood pack",
            contents = { blood = 5.0 },
        },
    },
}

local prototype_prefix = content.id .. "."
local random_prototype = prototype_prefix .. "random"
local typed_indices: { [string]: number } = {}
for index, id in ipairs(blood_identity.IDS) do
    typed_indices[prototype_prefix .. id] = index - 1
end

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:" .. content.id, {
        prototype = content.id,
    })

    behavior:handle(
        "interaction.use",
        { kind = "replace", route = "interact" },
        function(ev: InteractionUsePayload)
            local subject_prototype = ev.subject.prototype
            if subject_prototype ~= content.id
                and (subject_prototype == nil
                    or subject_prototype:sub(1, #prototype_prefix) ~= prototype_prefix)
            then
                return { replaced = false }
            end

            local implement = ev.implement
            if implement ~= nil and sim.matter_read(implement) ~= nil then
                return true
            end
            return { replaced = false }
        end
    )

    sim.handle("entity.initialize.done", { kind = "react" }, function(ev: EntityInitializeDonePayload)
        if ev.outcome ~= "completed" then
            return
        end

        local prototype = ev.entity.prototype
        if prototype == random_prototype then
            local index = math.floor(
                sim.random_for("blood_pack_type", ev.entity) * #blood_identity.IDS
            )
            blood_identity.stamp_vessel(ev.entity, index)
            return
        end

        local index = prototype ~= nil and typed_indices[prototype] or nil
        if index ~= nil then
            blood_identity.stamp_vessel(ev.entity, index)
        end
    end)
end

return content
