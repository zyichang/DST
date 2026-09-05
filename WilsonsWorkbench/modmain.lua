--[[ Wilson's Workbench ------------------------------------------------------

Gives EVERY character Wilson's material-transmutation recipes, at the vanilla
Alchemy Engine (researchlab2, TECH.SCIENCE_TWO).

Vanilla declares these in scripts/recipes.lua as TECH.NONE recipes locked
behind builder_skill = "wilson_alchemy_N", so only Wilson can ever see them.
We re-declare the same conversions against SCIENCE_TWO instead.

nounlock = true means the recipe is never permanently learned (see
Builder:UnlockRecipe, which early-returns on nounlock recipes), so the
Alchemy Engine stays a hard requirement every single time.

The vanilla ratios are deliberately lossy round-trips - 3 logs -> 6 twigs ->
2 logs - so exposing them to everyone creates no material exploit.

----------------------------------------------------------------------------]]

local _G        = GLOBAL
local STRINGS   = _G.STRINGS
local TECH      = _G.TECH
local Ingredient = _G.Ingredient

--------------------------------------------------------------------------
-- A browsable tab so the recipes are easy to find.
-- (nounlock recipes are auto-filed under CRAFTING_FILTERS.CRAFTING_STATION,
--  but the Alchemy Engine has is_crafting_station = false, so that tab never
--  appears for it. Our own filter avoids touching vanilla PROTOTYPER_DEFS.)
--------------------------------------------------------------------------
local FILTER = "WILSON_TRANSMUTE"

STRINGS.UI.CRAFTING_FILTERS[FILTER] = "Transmutation"

AddRecipeFilter({
    name  = FILTER,
    atlas = function() return _G.resolvefilepath(_G.CRAFTING_ICONS_ATLAS) end,
    image = "filter_refine.tex",
})

--------------------------------------------------------------------------
-- Recipe table:  { suffix, ingredients, product, numtogive, display name }
--------------------------------------------------------------------------
local TRANSMUTES =
{
    -- wood ---------------------------------------------------------------
    { "log",        { {"twigs", 3} },                    "log",        1, "Log" },
    { "twigs",      { {"log", 1} },                      "twigs",      2, "Twigs" },

    -- gems ---------------------------------------------------------------
    { "bluegem",    { {"redgem", 2} },                   "bluegem",    1, "Blue Gem" },
    { "redgem",     { {"bluegem", 2} },                  "redgem",     1, "Red Gem" },
    { "purplegem",  { {"bluegem", 1}, {"redgem", 1} },   "purplegem",  1, "Purple Gem" },
    { "orangegem",  { {"purplegem", 3} },                "orangegem",  1, "Orange Gem" },
    { "yellowgem",  { {"orangegem", 3} },                "yellowgem",  1, "Yellow Gem" },
    { "greengem",   { {"yellowgem", 3} },                "greengem",   1, "Green Gem" },
    { "opalpreciousgem",
      { {"redgem",1}, {"bluegem",1}, {"purplegem",1}, {"orangegem",1}, {"yellowgem",1}, {"greengem",1} },
                                                         "opalpreciousgem", 1, "Iridescent Gem" },

    -- stone --------------------------------------------------------------
    { "flint",      { {"rocks", 3} },                    "flint",      1, "Flint" },
    { "rocks",      { {"flint", 2} },                    "rocks",      1, "Rocks" },
    { "marble",     { {"cutstone", 2} },                 "marble",     1, "Marble" },
    { "cutstone",   { {"marble", 1} },                    "cutstone",   1, "Cut Stone" },
    { "moonrocknugget", { {"marble", 2} },               "moonrocknugget", 1, "Moon Rock" },

    -- metal --------------------------------------------------------------
    { "goldnugget", { {"nitre", 3} },                    "goldnugget", 1, "Gold Nugget" },
    { "nitre",      { {"goldnugget", 2} },               "nitre",      1, "Nitre" },

    -- meat ---------------------------------------------------------------
    { "meat",       { {"smallmeat", 3} },                "meat",       1, "Meat" },
    { "smallmeat",  { {"meat", 1} },                     "smallmeat",  2, "Morsel" },
    -- NEW (not in vanilla): mirrors the meat pair for dried meat.
    { "smallmeat_dried", { {"meat_dried", 1} },          "smallmeat_dried", 2, "Small Jerky" },

    -- animal products ----------------------------------------------------
    { "beardhair",   { {"beefalowool", 2} },             "beardhair",   1, "Beard Hair" },
    { "beefalowool", { {"beardhair", 2} },               "beefalowool", 1, "Beefalo Wool" },
    { "boneshard",   { {"houndstooth", 2} },             "boneshard",   1, "Bone Shards" },
    { "houndstooth", { {"boneshard", 2} },               "houndstooth", 1, "Hound's Tooth" },
    -- NEW (not in vanilla): pig skin into bunny puff.
    { "manrabbit_tail", { {"pigskin", 1} },              "manrabbit_tail", 1, "Bunny Puff" },

    -- BUFFED: vanilla asks for 6 Rot, this mod asks for 3.
    { "poop",        { {"spoiled_food", 3} },            "poop",        1, "Manure" },

    -- shadow allegiance --------------------------------------------------
    { "horrorfuel",  { {"dreadstone", 1} },              "horrorfuel",  2, "Pure Horror" },
    { "dreadstone",  { {"horrorfuel", 3} },              "dreadstone",  1, "Dreadstone" },
    { "nightmarefuel", { {"horrorfuel", 1} },            "nightmarefuel", 2, "Nightmare Fuel" },

    -- lunar allegiance ---------------------------------------------------
    { "purebrilliance",      { {"moonglass_charged", 3} }, "purebrilliance",      1, "Pure Brilliance" },
    { "moonglass_charged",   { {"purebrilliance", 1} },    "moonglass_charged",   2, "Infused Moon Shard" },
}

--------------------------------------------------------------------------
-- Register them all
--------------------------------------------------------------------------
local PREFIX = "ww_transmute_"

for _, entry in ipairs(TRANSMUTES) do
    local suffix, ings, product, numtogive, display = entry[1], entry[2], entry[3], entry[4], entry[5]
    local recipe_name = PREFIX .. suffix

    local ingredients = {}
    for i, ing in ipairs(ings) do
        ingredients[i] = Ingredient(ing[1], ing[2])
    end

    AddRecipe2(recipe_name, ingredients, TECH.SCIENCE_TWO,
        {
            product   = product,
            numtogive = numtogive,
            nounlock  = true,                       -- never learned; needs the Engine every time
            image     = product .. ".tex",
            description = recipe_name,
        },
        { FILTER }
    )

    STRINGS.NAMES[string.upper(recipe_name)] = display

    local from = {}
    for _, ing in ipairs(ings) do
        table.insert(from, ing[2] .. "x " .. ing[1])
    end
    STRINGS.RECIPE_DESC[string.upper(recipe_name)] =
        "Transmute " .. table.concat(from, " + ") .. "."
end
