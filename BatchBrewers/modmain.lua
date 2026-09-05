--[[ Batch Brewers ----------------------------------------------------------

Two structures that run Heap of Foods brew recipes a whole stack at a time.

HOF integration relies on three things it already exposes publicly:
  * global AddBrewerRecipe(brewer, recipe)      -- hof_brewing.lua
  * exported table  brewing.recipes[prefab]     -- keyed by structure prefab
  * containers.params.brewer                    -- its container layout/itemtest

Nothing is copied from HOF. Art is vanilla (monkey_barrel / graveurn) tinted,
so no third-party assets are redistributed.

SAFETY WITHOUT HOF: every HOF access is guarded. The prefabs still register
(so worlds saved with them do not crash on load), but no build recipe is
offered and their containers accept nothing.

----------------------------------------------------------------------------]]

local _G        = GLOBAL
local TECH      = _G.TECH
local STRINGS   = _G.STRINGS
local Ingredient = _G.Ingredient

--------------------------------------------------------------------------
-- 1. Detect Heap of Foods without ever hard-erroring
--------------------------------------------------------------------------
-- NOTE: the mod environment (scripts/mods.lua CreateEnvironment) only exposes
-- pairs, ipairs, print, math, table, type, string, tostring, require, Class,
-- TUNING and GLOBAL. pcall is NOT among them, so it must come from GLOBAL.
local ok, brewing = _G.pcall(_G.require, "hof_brewing")
if not ok then
    brewing = nil
end

local HAS_HOF = brewing ~= nil
    and type(brewing) == "table"
    and brewing.recipes ~= nil
    and _G.rawget(_G, "AddBrewerRecipe") ~= nil

-- Read by the prefab file.
_G.BATCHBREWERS_HAS_HOF = HAS_HOF

if not HAS_HOF then
    print("[Batch Brewers] Heap of Foods not detected - structures will be inert.")
end

--------------------------------------------------------------------------
-- 2. Options: language + structure size
--------------------------------------------------------------------------
local lang_cfg = GetModConfigData("language") or "auto"
local scale    = GetModConfigData("scale") or 1.0

if lang_cfg == "auto" then
    -- LOC.GetLanguage() returns the game's language code, e.g. "zh", "zht".
    local code = _G.LOC ~= nil and _G.LOC.GetLanguage ~= nil and _G.LOC.GetLanguage() or nil
    lang_cfg = (code ~= nil and string.sub(tostring(code), 1, 2) == "zh") and "zh" or "en"
end

local ZH = lang_cfg == "zh"

-- Read by the prefab file.
_G.BATCHBREWERS_SCALE = scale

--------------------------------------------------------------------------
-- 3. Assets. Vanilla anim builds only; icons are our own.
--------------------------------------------------------------------------
PrefabFiles = { "batchbrewers" }

Assets = {
    Asset("ANIM",  "anim/portable_cook_pot.zip"), -- Warly's pot: art for both structures
    Asset("ANIM",  "anim/ui_chest_3x1.zip"),    -- vanilla 3-slot container UI

    Asset("ATLAS", "images/inventoryimages/bb_glasskeg.xml"),
    Asset("IMAGE", "images/inventoryimages/bb_glasskeg.tex"),
    Asset("ATLAS", "images/inventoryimages/bb_saucecrock.xml"),
    Asset("IMAGE", "images/inventoryimages/bb_saucecrock.tex"),
}

--------------------------------------------------------------------------
-- 4. Strings, in both languages
--------------------------------------------------------------------------
local T = ZH and
{
    jar_name   = "玻璃酱罐",
    keg_name   = "郁金香酿酒杯",
    jar_recipe = "一次性发酵一整组。",
    keg_recipe = "一次性酿造一整组。",
    jar_desc   = "祖母的酱罐，放大版。",
    keg_desc   = "工业级产量的酒。",
    brewing_l  = "还要等好一会儿。",
    brewing_s  = "快好了。",
    done       = "一整批，好了。",
    empty      = "要整组，不是一点点。",
    burnt      = "唉，烧掉了。",
}
or
{
    jar_name   = "Glass Sauce Jar",
    keg_name   = "Tulip Brewing Glass",
    jar_recipe = "Ferments a whole stack at once.",
    keg_recipe = "Brews a whole stack at once.",
    jar_desc   = "Grandmother's crock, scaled up.",
    keg_desc   = "Industrial quantities of beer.",
    brewing_l  = "This will take a while.",
    brewing_s  = "Almost ready.",
    done       = "A whole batch, done.",
    empty      = "It takes stacks, not scraps.",
    burnt      = "Well, that is that.",
}

STRINGS.NAMES.BB_SAUCECROCK = T.jar_name
STRINGS.NAMES.BB_GLASSKEG   = T.keg_name

STRINGS.RECIPE_DESC.BB_SAUCECROCK = T.jar_recipe
STRINGS.RECIPE_DESC.BB_GLASSKEG   = T.keg_recipe

STRINGS.CHARACTERS.GENERIC.DESCRIBE.BB_SAUCECROCK =
{
    GENERIC       = T.jar_desc,
    BREWING_LONG  = T.brewing_l,
    BREWING_SHORT = T.brewing_s,
    DONE          = T.done,
    EMPTY         = T.empty,
    BURNT         = T.burnt,
}
STRINGS.CHARACTERS.GENERIC.DESCRIBE.BB_GLASSKEG =
{
    GENERIC       = T.keg_desc,
    BREWING_LONG  = T.brewing_l,
    BREWING_SHORT = T.brewing_s,
    DONE          = T.done,
    EMPTY         = T.empty,
    BURNT         = T.burnt,
}

--------------------------------------------------------------------------
-- 4. Inherit every HOF brew recipe onto our two structures.
--    brewing.recipes is keyed by the structure's prefab name, which is why
--    a fresh prefab matches nothing until we register it here.
--------------------------------------------------------------------------
if HAS_HOF then
    local AddBrewerRecipe = _G.AddBrewerRecipe

    local INHERIT = {
        bb_saucecrock = "kyno_preservesjar",
        bb_glasskeg   = "kyno_woodenkeg",
    }

    for ours, theirs in pairs(INHERIT) do
        local src = brewing.recipes[theirs]
        if src ~= nil then
            local n = 0
            for _, recipe in pairs(src) do
                -- Registering the same recipe table under our prefab too.
                -- no_brewbook avoids duplicating HOF's brew book entries.
                AddBrewerRecipe(ours, recipe)
                n = n + 1
            end
            print(string.format("[Batch Brewers] %s inherited %d recipes from %s", ours, n, theirs))
        else
            print("[Batch Brewers] no recipes found for " .. theirs)
        end
    end
end

--------------------------------------------------------------------------
-- 5. Build recipes - only offered when HOF is present.
--------------------------------------------------------------------------
if HAS_HOF then
    local function BrewerRecipe(name, image)
        AddRecipe2(name,
            {
                Ingredient("boards", 3),                -- inherited from HOF
                Ingredient("rope", 2),
                Ingredient("nitre", 3),
                Ingredient("yellowgem", 1),             -- ours
                Ingredient("townportaltalisman", 5),    -- Desert Stone
            },
            TECH.SCIENCE_TWO,                            -- Alchemy Engine
            {
                placer      = name .. "_placer",
                min_spacing = 1,
                atlas       = "images/inventoryimages/" .. image .. ".xml",
                image       = image .. ".tex",
            },
            { "COOKING", "STRUCTURES" }     -- findable under 烹饪 as well
        )
    end

    BrewerRecipe("bb_saucecrock", "bb_saucecrock")
    BrewerRecipe("bb_glasskeg",   "bb_glasskeg")

    ----------------------------------------------------------------------
    -- Farm extra: 1 Large Chicken Egg -> 4 Chicken Eggs.
    -- Lives here rather than in Wilson's Workbench because these are Heap of
    -- Foods prefabs and this mod already requires HOF outright, so there is
    -- no conditional behaviour to get wrong.
    ----------------------------------------------------------------------
    AddRecipe2("bb_chicken_egg_split",
        { Ingredient("kyno_chicken_egg_large", 1) },
        TECH.SCIENCE_TWO,                       -- Alchemy Engine
        {
            product     = "kyno_chicken_egg",
            numtogive   = 4,
            nounlock    = true,                 -- never learned; needs the Engine
            image       = "kyno_chicken_egg.tex",
            description = "bb_chicken_egg_split",
        },
        { "GARDENING", "COOKING" }
    )

    STRINGS.NAMES.BB_CHICKEN_EGG_SPLIT       = ZH and "鸡蛋" or "Chicken Eggs"
    STRINGS.RECIPE_DESC.BB_CHICKEN_EGG_SPLIT = ZH
        and "把一个大鸡蛋分成四个鸡蛋。"
        or  "Split one large chicken egg into four."
end
