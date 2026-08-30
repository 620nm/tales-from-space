-- What the station's unclaimed dead are wearing.
--
-- Standard issue with no role attached (docs/CONTENT-SCHEMA.md §1.7a):
-- a job is a slot on the board that anybody may take, and "cadaver" is
-- not a job. The morgue drawer's `cadaver` variant names this set on
-- its body-stock row (content/structures/morgue.luau).
--
-- NOT PORTED. tg's lost crew are dressed by a weighted character
-- scenario and then sealed into a tagged body bag
-- (code/modules/lost_crew/lost_crew_manager.dm:24-45;
-- code/modules/mapping/mapping_helpers.dm:955-966); Tales from Space
-- has neither character scenarios nor body bags, so the grey jumpsuit
-- every other outfit starts from is what they are found in. No ID: an
-- unidentified body is the point of a morgue drawer.
return {
    id = "cadaver",
    outfit = {
        { slot = "uniform", item = "uniform_grey" },
    },
}
