-- The ground roles beyond the engine's `surface` and `deep` (the engine's
-- docs/mapping/generated-ground.md): a map's ground hint names a role, and
-- each environment's `ground` table says which blend fills it there.
--
-- `rock`: bare bedrock where the ground stands up out of the soil or ice,
-- a ridge or an outcrop column.
return {
    id = "ground_roles",
    entries = {
        { id = "rock", label = "lunatic/tfs:ground.role.rock" },
    },
}
