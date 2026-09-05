name = "Wilson's Workbench"
version = "1.1.0"

-- Built from `version` so the number in the description can never drift.
description = "Wilson's Workbench  v" .. version .. [[


Gives EVERY character Wilson's material-transmutation recipes, at the vanilla
Alchemy Engine. No new structure to build - just stand at your Alchemy Engine
and open the new "Transmutation" tab.

30 conversions: wood, all six gems (including the Iridescent Gem), stone,
marble, moon rock, gold, nitre, meat, jerky, wool, beard hair, bone shards,
hound's teeth, manure, and the shadow / lunar materials.

The recipes are never permanently learned, so the Alchemy Engine is always
required. Vanilla's ratios are lossy round-trips, so nothing here is
exploitable.

Changes from vanilla:
  * Manure costs 3 Rot instead of 6.
  * NEW: 1 Jerky -> 2 Small Jerky
  * NEW: 1 Pig Skin -> 1 Bunny Puff

v1.1.0 - dropped the custom workbench; recipes now live on the Alchemy Engine.
v1.0.1 - mod icon.
v1.0.0 - first test build.]]

author = "yichangzhang"
forumthread = ""

-- 10 is the current API version for Don't Starve Together.
api_version = 10

-- Mod icon shown in the in-game Mods list.
icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

-- Adds recipes, so the server drives it and every client needs it too.
all_clients_require_mod = true
client_only_mod = false

server_filter_tags = { "transmute", "alchemy", "wilson" }
