name = "Batch Brewers"
version = "1.2.0"

-- Built from `version` so the number in the description can never drift.
description = "Batch Brewers  v" .. version .. [[


Two structures that brew Heap of Foods recipes a WHOLE STACK at a time.

  * Glass Sauce Jar   - every Preserves Jar recipe, in batches
  * Tulip Brewing Glass - every Wooden Keg recipe, in batches

Fill each slot with a stack and you get as many batches as the SMALLEST
stack. Only that many are consumed from each slot - leftovers stay put.
Example: 10/20/15 gives 10 batches and leaves 0/10/5 behind.

Build cost (Alchemy Engine): 3 Boards, 2 Rope, 3 Nitre, 1 Yellow Gem,
5 Desert Stones. Found under the Cooking tab.

Also adds: 1 Large Chicken Egg -> 4 Chicken Eggs (Gardening tab).

Options: interface language (Auto / English / Chinese) and structure size.

REQUIRES Heap of Foods. Without it, the structures cannot be built and do
nothing at all - they will not throw errors.


CHANGELOG

v1.2.0  Added a farm conversion: 1 Large Chicken Egg -> 4 Chicken Eggs, at the
        Alchemy Engine, listed under Gardening and Cooking.
v1.1.4  Fixed long recipes yielding only one item. The batch count was kept on
        the component but not saved, and Brewer:OnSave stores only done /
        product / remainingtime / chef_id / ingredient_prefabs. Butter takes
        cooktime 96 (4 days), so it practically always spanned a world save and
        came back as 1 batch. The count is now persisted across saves.
v1.1.3  Fixed leftover ingredients being destroyed. Heap of Foods' StartCooking
        calls container:DestroyContents(), which eats WHOLE stacks, so 10/20/15
        consumed everything for only 10 batches. Now each slot loses exactly
        the batch count and the remainder stays in the slot: 10/20/15 gives
        10 batches and leaves 0/10/5.
v1.1.2  Both structures now use the Portable Crock Pot art as-is, untinted
        and unscaled. Names are unchanged.
v1.1.1  Default size is now 1.0x (normal), adjustable in the options.
        Replaced character-owned art: the jar no longer uses Wortox's soul jar
        and the glass no longer uses Wendy's urn. Both now use neutral vanilla
        builds - a cooking vessel and a decorative vase.
        The brewing glass is now tulip-shaped.
v1.1.0  Redesigned both structures: cylindrical glass jar and a stemmed
        goblet, replacing the round urn.
        Structure size is now adjustable in the options (the old one was too
        small); default 1.5x.
        Added a language option (Auto / English / Chinese) and Chinese text.
v1.0.4  Icons were 256x256 and rendered as huge flat planes; rebuilt at 64x64
        with half-texel UVs, matching how working single-item atlases are made.
        Replaced the monkey barrel art (it was the pirate monkeys' HOUSE).
        Real 3-slot container with a Brew button. Heap of Foods keeps its
        layouts in a file-local table and overrides containers.widgetsetup,
        so they cannot be inherited - an equivalent layout is declared here
        using vanilla ui_chest_3x1 art.
v1.0.3  Fixed a client crash when opening the container: container params were
        only registered on the server, so clients hit
        containerwidget.lua:32 "attempt to index local 'widget'".
v1.0.2  Recipes now appear under the Cooking tab.
        Fixed load order (priority -20) so Heap of Foods is actually detected.
        Fixed a dropped placer that made the jar unplaceable.
v1.0.1  Fixed a crash on server start: pcall is not available in the mod
        environment and must be reached through GLOBAL.
v1.0.0  First release.]]

author = "yichangzhang"
forumthread = ""

api_version = 10

-- Load order. mods.lua sorts with "apriority > bpriority", so HIGHER loads
-- FIRST. Heap of Foods declares priority = -15, so we must go lower than that
-- to load AFTER it - otherwise hof_brewing is not yet on the require path and
-- AddBrewerRecipe does not exist yet.
priority = -20

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = true
client_only_mod = false

-- Read by modindex.lua:571. The Mods menu will auto-enable Heap of Foods,
-- or warn that it is missing. Only honoured for non-client-only mods.
mod_dependencies = {
    { workshop = "workshop-2334209327" },   -- Heap of Foods
}

server_filter_tags = { "brewing", "batch", "heap of foods" }

configuration_options =
{
    {
        name = "language",
        label = "Language / 语言",
        hover = "Text language. Auto follows the game's own language.",
        options =
        {
            { description = "Auto / 自动", data = "auto", hover = "Follow the game language" },
            { description = "English",     data = "en",   hover = "Always English" },
            { description = "中文",         data = "zh",   hover = "Always Chinese" },
        },
        default = "auto",
    },

    {
        name = "scale",
        label = "Size / 大小",
        hover = "How large the built structures appear.",
        options =
        {
            { description = "1.0x", data = 1.0,  hover = "Normal size (default)" },
            { description = "1.25x", data = 1.25 },
            { description = "1.5x", data = 1.5 },
            { description = "1.75x", data = 1.75 },
            { description = "2.0x", data = 2.0 },
            { description = "2.5x", data = 2.5 },
        },
        default = 1.0,
    },
}
