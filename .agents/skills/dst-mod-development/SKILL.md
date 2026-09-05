
---
name: dst-mod-development
description: Build, debug and publish Don't Starve Together mods. Use when the user wants to write a DST mod, add recipes or prefabs, make mod art or icons, hook another mod, diagnose a DST crash or a server that will not start, or upload to the Steam Workshop.
---
DST punishes reasoning from first principles. Almost every bug in a new mod is a
platform convention you cannot deduce — a missing global, a load-order rule, a
client/server split. So the governing move is **precedent**: before writing
anything, find the vanilla file or installed mod that already does it, and copy
its shape.

## Workflow

1. **Read the game's own source.** It is not on disk as files; extract it.
   Completion criterion: you have located the vanilla prefab, component or
   recipe that does the thing you are about to write.
2. **Find a precedent for every unfamiliar mechanism** — container widget,
   prototyper, custom action, save/load. Copy its structure, not just its idea.
3. **Write it**, routing every non-whitelisted global through `GLOBAL`.
4. **Verify in the strict sandbox** (below) before the user launches anything.
5. **Read the real log** after a failure — usually the *backup* log, not the
   live one.

## Extracting the game source

```bash
cd "$HOME/.local/share/Steam/steamapps/common/Don't Starve Together/data/databundles"
TMP=$(mktemp -d); unzip -o -q scripts.zip -d "$TMP"   # 3500+ prefabs, all components
grep -rn 'SetBuild("wanted_build")' "$TMP/scripts/prefabs/"
rm -rf "$TMP"                                          # always clean up
```

Most-consulted files: `recipes.lua`, `containers.lua`, `constants.lua`,
`techtree.lua`, `modutil.lua` (the whole mod API), `mods.lua`,
`components/<name>.lua`, `prefabs/<name>.lua`.

Chinese/English item names: any installed mod's `chinese_s.po`, keyed
`STRINGS.NAMES.<PREFAB>`. Vanilla anim builds:
`data/anim/*.zip` (3500+, greppable by shape word).

## The mod environment whitelist

`modmain.lua` and `modinfo.lua` run in a sandbox that exposes **only**:

```
pairs  ipairs  print  math  table  type  string  tostring  require  Class
TUNING  GLOBAL  modname  MODROOT  modimport
```

Everything else must come from `GLOBAL` — `_G.pcall`, `_G.rawget`, `_G.LOC`,
`_G.resolvefilepath`. `pcall` is the classic one: calling it bare aborts
`modmain`, which fails the mod, which **stops the server booting**.

Prefab files under `scripts/prefabs/` are *not* sandboxed — they get the real
globals, so `pcall`, `Vector3`, `SpawnPrefab` work directly there. Reading an
undefined global returns `nil` rather than erroring, which is how a prefab file
reads a flag `modmain` set on `GLOBAL`.

## Load order

`mods.lua` sorts with `apriority > bpriority`: **higher priority loads first.**
To run *after* another mod (so its globals and `require` paths exist), set a
*lower* number than theirs.

```lua
priority = -20        -- Heap of Foods is -15, so we load after it
```

Symptom of getting this wrong: your dependency-detection says the other mod is
absent even though it is installed.

`mod_dependencies` in `modinfo.lua` makes the Mods menu auto-enable a
dependency, but does **not** guarantee load order. It is honoured only when
`client_only_mod` is false.

```lua
mod_dependencies = { { workshop = "workshop-2334209327" } }
```

## Client and server

Anything the UI needs must exist on the client, and container params must be
registered **before** `inst.entity:SetPristine()`. Registering them inside the
`ismastersim` branch leaves clients with `containers.params[name] == nil` and
crashes `containerwidget.lua:32` "attempt to index local 'widget'".

```lua
EnsureContainerParams(name)          -- both sides
inst.entity:SetPristine()

if not TheWorld.ismastersim then
    inst.OnEntityReplicated = function(inst)
        inst.replica.container:WidgetSetup(name)
    end
    return inst
end
```

## Lua traps that bite in DST specifically

**Multiple returns truncate.** A call in a non-final position yields one value,
so `return MakeThing(a), MakeThing(b)` silently drops the first thing's placer.
Capture explicitly.

**Component state is not saved.** A field you add to a component vanishes on
world save unless you wrap its `OnSave`/`OnLoad`. Long-running state (a brew
timer, a batch count) will always outlive a save.

```lua
local _OnSave = c.OnSave
c.OnSave = function(self)
    local data = _OnSave(self) or {}
    data.my_field = self.my_field
    return data
end
```

**Mutating during `pairs()`.** `container:RemoveItem` edits the slots table.
Snapshot to an array first, then iterate.

## Recipes

```lua
AddRecipe2(name, {Ingredient("boards", 3)}, TECH.SCIENCE_TWO, {
    product = "x", numtogive = 4,
    nounlock = true,                 -- never learned; the station is required every time
    image = "x.tex", placer = name.."_placer", min_spacing = 1,
}, { "COOKING", "STRUCTURES" })
```

Filter names (`recipes_filter.lua`): `TOOLS LIGHT PROTOTYPERS REFINE WEAPONS ARMOUR CLOTHING RESTORATION MAGIC DECOR STRUCTURES CONTAINERS COOKING GARDENING FISHING SEAFARING RIDING WINTER SUMMER RAIN CHARACTER`.

`nounlock` recipes are auto-filed under `CRAFTING_FILTERS.CRAFTING_STATION`,
which only surfaces for prototypers whose `PROTOTYPER_DEFS` entry has
`is_crafting_station = true`. For an ordinary station, add your own filter with
`AddRecipeFilter` or pass a real filter, or the recipe is unreachable.

New tech branch: `TechTree.AVAILABLE_TECH` is exported, and `player_classified`
falls back to `string.lower(v).."level"`, so appending works without patching
caches. Also set `TECH.NONE[BRANCH] = 0`, since `TECH.NONE` is built before mods
load.

## Art

**Icons are achievable; world models are not** (on Linux, without Klei's
Windows autocompiler — `zipanim.py`, `compiler_scripts/` and `buildtools/` ship
only with the Windows Mod Tools).

For the world, use a **vanilla build** and change it:

```lua
inst.AnimState:SetBank("cook_pot"); inst.AnimState:SetBuild("cook_pot")
inst.AnimState:PlayAnimation("idle_empty")
inst.AnimState:SetMultColour(0.7, 0.9, 0.95, 0.6)   -- alpha < 1 reads as glass
inst.AnimState:SetScale(s, s)                        -- vanilla structures are scale 1.0
```

Pick a build with no character owner — reusing Wortox's or Wendy's items reads
as their item, not yours. Confirm the bank/build/anim names from the prefab that
uses it; never guess anim names. Skip `MakeSnowCovered` unless the build has
snow symbols.

Icons: **64×64, DXT5, full mip chain, half-texel UV inset**. Anything larger
renders as a giant flat plane.

```xml
<Atlas><Texture filename="x.tex" /><Elements>
<Element name="x.tex" u1="0.0078125" u2="0.9921875" v1="0.0078125" v2="0.9921875" />
</Elements></Atlas>
```

KTEX header, verified byte-identical against Klei's own files: magic `KTEX`,
then one `<I` bitfield — `platform(4) | pixel_format(5) | texture_type(4) | mipmap_count(5) | flags(2) | remainder(12)` — with `pixel_format=2` (DXT5),
`texture_type=1` (2D), `flags=3`, `remainder=0xFFF`; then one `<HHHI` record per
mip (`width, height, pitch = width*4, datasize`); then the mip payloads. Produce
DXT5 with `magick in.png -define dds:compression=dxt5 -define dds:mipmaps=0 out.dds` and strip the 128-byte DDS header. Flip the image vertically first —
Klei's tools do.

## Verification

`luajit` is the lever: load `modmain.lua` in a sandbox that mirrors the real
whitelist, with an `__index` trap so any non-whitelisted global raises. A
permissive sandbox is worse than none — it will pass code that cannot run.

```lua
local env = { pairs=pairs, ipairs=ipairs, print=print, math=math, table=table,
  type=type, string=string, tostring=tostring, Class=function() end,
  TUNING={}, GLOBAL=fake_globals, modname="t", MODROOT="./",
  AddRecipe2=..., Asset=function() end, GetModConfigData=function(k) ... end }
env.env = env
setmetatable(env, {__index = function(_, k) error("BLOCKED global: "..k, 2) end})
local f = assert(loadfile("modmain.lua")); setfenv(f, env); assert(pcall(f))
```

Run every branch: dependency present *and* absent, each language, each config
value. Also `luajit -bl file.lua` for a syntax-only check, and load the prefab
file with `Prefab`/`MakePlacer` stubbed to count returned values.

## Reading failures

| symptom                 | file to read                                                                  |
| ----------------------- | ----------------------------------------------------------------------------- |
| server will not start   | `~/.klei/DoNotStarveTogether/<id>/Cluster_1/Master/backup/server_log/*.txt` |
| client crash / UI error | `~/.klei/DoNotStarveTogether/client_log.txt`                                |
| mod loaded at all?      | grep the log for the mod's folder name                                        |

**The live `server_log.txt` is overwritten by the next successful start**, so a
failed boot is only in `backup/server_log/`. Grep for `MOD ERROR`, `LUA ERROR`,
`attempt to`.

Fast iteration beats uploading: copy the mod into
`Don't Starve Together/mods/<name>/` and set in `mods/modsettings.lua`:

```lua
ForceEnableMod("<name>")     -- loads every launch
EnableModDebugPrint()        -- extra startup logging
DisableModDisabling()        -- stop auto-disable after a crash
EnableModError()             -- fail loudly instead of silently
```

## Publishing

Steam Library → show **Tools** → **Don't Starve Mod Tools** → top option is the
uploader → **Add** → point *Update Data* at the mod folder → preview image must
be `.png`/`.jpg`.

- `version` in `modinfo.lua` must **change** every upload or it is rejected.
  Derive the description from it (`description = "Name v" .. version .. [[...]]`)
  so they cannot drift.
- When updating, tick **only** *Update Data*, or you overwrite the Workshop
  description with the short in-game one.
- **~100 MB limit.** Forking a large mod is not possible for this reason alone.
- Workshop **change notes** are typed in the uploader; `modinfo.lua` cannot set
  them. Keep a changelog in the description and paste it across.
- Errors land in `ModUploader.log`; look up the `EResult` code.

## Licensing

Vanilla Klei assets are fine — every mod uses them, and `Asset("ANIM", ...)`
references the player's own install rather than redistributing anything.

Another modder's assets are not. Absent an explicit licence, default copyright
applies, and the Subscriber Agreement requires you to hold the rights. Community
practice around reuploading *abandoned* mods does not extend to a maintained
one. Referencing another mod's file by path at runtime redistributes nothing and
is materially different from bundling it — but check whether the reference even
resolves.

## Hooking another mod

Prefer additive: new prefabs and recipes that leave the other mod untouched, so
its updates cannot break you and users can run both.

- Its globals: `global("Fn")` declarations are reachable as `_G.Fn`.
- Its modules: `require("their_module")` — Lua caches modules, so you get the
  same tables they use. Guard with `_G.pcall`.
- Its components: `AddComponentPostInit("name", fn)` matches by name and works
  cross-mod.
- Its container layouts may **not** be reachable: a mod can override
  `containers.widgetsetup` and read a file-local table. Check before assuming
  you can inherit; declare an equivalent layout instead.
