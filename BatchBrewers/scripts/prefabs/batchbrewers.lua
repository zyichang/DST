--[[ batchbrewers ------------------------------------------------------------

The two structures. Art is vanilla, recoloured:
  bb_glasskeg   - bank "barrel"   build "monkey_barrel"  anims idle/hit/shake
  bb_saucecrock - bank "graveurn" build "graveurn"       anims idle_empty/idle_pre

Batching, following Legion's ComputAndCost approach:
  batches = the SMALLEST stack across the filled slots.
Because HOF's recipe tests count one entry per SLOT, a recipe needing
"2 berries + 1 sweetener" is satisfied by berries in two slots. Filling each
of those slots with 40 and the sweetener slot with 40 therefore consumes
80 berries + 40 sweetener and yields 40 batches - proportional, no exploit.

HOF's own StartCooking already destroys the whole slot contents, so the input
side needs no changes. Only the output has to be multiplied.

----------------------------------------------------------------------------]]

require "prefabutil"

-- Prefab files run in the game's global environment, so the flag modmain set
-- is read directly. An undefined global simply reads as nil here.
local HAS_HOF = BATCHBREWERS_HAS_HOF

local brewing = nil
if HAS_HOF then
    local ok, mod = pcall(require, "hof_brewing")
    if ok then brewing = mod end
end

--------------------------------------------------------------------------
-- Container params.
-- Built lazily on first use so we do not depend on mod load order: by the
-- time a prefab is constructed, HOF's containers.params.brewer exists.
--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- Container params.
--
-- IMPORTANT: Heap of Foods does NOT publish its layouts into
-- containers.params. It overrides containers.widgetsetup and reads a table
-- that is *local* to its own file, so params.brewer is unreachable from here.
-- That is why an earlier version produced one big empty box: our fallback
-- (zero slots) was used. So we declare our own equivalent layout instead.
--
-- HOF's widgetsetup override delegates unknown prefabs to the vanilla base,
-- which does read containers.params, so registering here works.
--
-- UI art is vanilla ui_chest_3x1 (3 slots in a row), not HOF's ui_brewer_1x3.
--------------------------------------------------------------------------
local function EnsureContainerParams(name)
    local containers = require("containers")
    if containers.params[name] ~= nil then
        return true
    end

    -- Reuse HOF's ingredient test if we can reach it; otherwise accept nothing.
    local okmod, brewmod = pcall(require, "hof_brewing")
    local IsBrewingIngredient = (okmod and type(brewmod) == "table") and brewmod.IsBrewingIngredient or nil

    local p =
    {
        widget =
        {
            slotpos =
            {
                Vector3(-(64 + 12), 0, 0),
                Vector3(0, 0, 0),
                Vector3(64 + 12, 0, 0),
            },

            animbank  = "ui_chest_3x1",
            animbuild = "ui_chest_3x1",

            pos = Vector3(0, 200, 0),

            buttoninfo =
            {
                text     = (STRINGS.ACTIONS ~= nil and STRINGS.ACTIONS.BREWER) or "Brew",
                position = Vector3(0, -80, 0),
            },
        },

        acceptsstacks = true,        -- the whole point of this mod
        type = "brewer",
    }

    p.itemtestfn = function(container, item, slot)
        if IsBrewingIngredient == nil then
            return false             -- no HOF: accept nothing, so nothing errors
        end
        return IsBrewingIngredient(item.prefab) and not container.inst:HasTag("burnt")
    end

    -- Same handoff HOF uses: fire its BREWER action, which calls StartCooking.
    p.widget.buttoninfo.fn = function(inst, doer)
        if ACTIONS.BREWER == nil then
            return
        end
        if inst.components.container ~= nil then
            BufferedAction(doer, inst, ACTIONS.BREWER):Do()
        elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
            SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.BREWER.code, inst, ACTIONS.BREWER.mod_name)
        end
    end

    p.widget.buttoninfo.validfn = function(inst)
        return inst.replica.container ~= nil and inst.replica.container:IsFull()
    end

    containers.params[name] = p
    return IsBrewingIngredient ~= nil
end

--------------------------------------------------------------------------
-- Batching helpers
--------------------------------------------------------------------------
local function CountBatches(inst)
    local container = inst.components.container
    if container == nil then
        return 1
    end

    local smallest = nil
    for _, item in pairs(container.slots) do
        local n = (item.components.stackable ~= nil and item.components.stackable:StackSize()) or 1
        if smallest == nil or n < smallest then
            smallest = n
        end
    end

    return math.max(1, smallest or 1)
end

-- Hand over the extra batches beyond the one HOF's Harvest already gave,
-- splitting across stacks so nothing is silently lost to the stack cap.
local function GiveExtra(inst, harvester, product, count)
    local guard = 0
    while count > 0 and guard < 200 do
        guard = guard + 1

        local loot = SpawnPrefab(product)
        if loot == nil then
            return
        end

        local per = 1
        if loot.components.stackable ~= nil then
            per = math.min(count, loot.components.stackable.maxsize)
            loot.components.stackable:SetStackSize(per)
        end

        if loot.components.perishable ~= nil then
            loot.components.perishable:StartPerishing()
        end

        if harvester ~= nil and harvester.components.inventory ~= nil then
            harvester.components.inventory:GiveItem(loot, nil, inst:GetPosition())
        else
            LaunchAt(loot, inst, nil, 1, 1)
        end

        count = count - per
    end
end

local function MakeBatching(inst)
    local b = inst.components.brewer
    if b == nil then
        return
    end

    local _StartCooking = b.StartCooking
    local _Harvest      = b.Harvest
    local _OnSave       = b.OnSave
    local _OnLoad       = b.OnLoad

    -- Persist the batch count. Brewer:OnSave only stores done/product/
    -- remainingtime/chef_id/ingredient_prefabs, so bb_batches was lost across
    -- any save or server restart. Long recipes (butter is cooktime 96 = 4 days)
    -- practically always span a save, which made them yield a single item.
    b.OnSave = function(self)
        local data = _OnSave(self) or {}
        if self.bb_batches ~= nil and self.bb_batches > 1 then
            data.bb_batches = self.bb_batches
        end
        return data
    end

    b.OnLoad = function(self, data)
        if data ~= nil and data.bb_batches ~= nil then
            self.bb_batches = data.bb_batches
        end
        return _OnLoad(self, data)
    end

    b.StartCooking = function(self, doer)
        -- Must be measured before the contents are consumed.
        local batches = CountBatches(self.inst)
        self.bb_batches = batches

        local container = self.inst.components.container
        local restore = nil

        if container ~= nil then
            -- HOF's StartCooking calls container:DestroyContents(), which
            -- destroys WHOLE stacks. That silently ate leftovers: 10/20/15
            -- consumed everything for only 10 batches.
            --
            -- Swap in a partial consume for the duration of that call, so each
            -- slot loses exactly `batches` and the remainder stays in the slot.
            -- 10/20/15 -> 10 batches, leaving 0/10/5.
            restore = container.DestroyContents

            container.DestroyContents = function(self2)
                -- Snapshot first: RemoveItem mutates the slots table, and
                -- mutating during pairs() is undefined behaviour in Lua.
                local items = {}
                for _, item in pairs(self2.slots) do
                    items[#items + 1] = item
                end

                for _, item in ipairs(items) do
                    local st = item.components.stackable
                    local n = (st ~= nil and st:StackSize()) or 1

                    if st ~= nil and n > batches then
                        st:SetStackSize(n - batches)     -- keep the remainder
                    else
                        self2:RemoveItem(item, true)
                        item:Remove()
                    end
                end
            end
        end

        local result = _StartCooking(self, doer)

        if container ~= nil and restore ~= nil then
            container.DestroyContents = restore
        end

        return result
    end

    b.Harvest = function(self, harvester)
        local batches = self.bb_batches or 1
        local product = self.product

        local per = 1
        if brewing ~= nil and product ~= nil then
            local recipe = brewing.GetBrewing(self.inst.prefab, product)
            per = (recipe ~= nil and recipe.stacksize) or 1
        end

        -- Let HOF do its normal single-batch harvest: brew book, perishing,
        -- empty-bottle refunds and so on all stay intact.
        local result = _Harvest(self, harvester)

        if product ~= nil and batches > 1 then
            GiveExtra(self.inst, harvester, product, (batches - 1) * per)
        end

        self.bb_batches = nil
        return result
    end
end

--------------------------------------------------------------------------
-- Shared structure body
--------------------------------------------------------------------------
local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
    inst.components.lootdropper:DropLoot()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")

    inst:Remove()
end

local function MakeBrewer(name, bank, build, idleanim, tint)
    local assets =
    {
        Asset("ANIM", "anim/" .. build .. ".zip"),
    }

    local function onhit(inst)
        if not inst:HasTag("burnt") then
            inst.AnimState:PlayAnimation(idleanim)
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        MakeObstaclePhysics(inst, .4)

        inst.MiniMapEntity:SetIcon(build .. ".png")

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(idleanim)
        -- tint is optional: nil means use the vanilla art exactly as-is
        if tint ~= nil then
            inst.AnimState:SetMultColour(tint[1], tint[2], tint[3], tint[4])
        end
        -- Scale stays available as an option; 1.0 leaves the art untouched.
        local s = BATCHBREWERS_SCALE or 1.0
        if s ~= 1.0 then
            inst.AnimState:SetScale(s, s)
        end

        inst:AddTag("structure")

        -- Container params must exist on the CLIENT too, before any widget is
        -- built. Doing this only inside the mastersim branch left clients with
        -- containers.params[name] == nil, which crashed containerwidget.lua:32
        -- ("attempt to index local 'widget'").
        EnsureContainerParams(name)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            -- Same pattern as HOF's own k_brewers.lua.
            inst.OnEntityReplicated = function(inst)
                if not inst:HasTag("burnt") then
                    inst.replica.container:WidgetSetup(name)
                end
            end

            return inst
        end

        -- Already ensured above (pre-pristine) so clients have it too; this is
        -- a no-op second call that just reports whether HOF's params existed.
        local has_container = EnsureContainerParams(name)

        inst:AddComponent("inspectable")
        inst:AddComponent("lootdropper")     -- required by onhammered

        inst:AddComponent("container")
        inst.components.container:WidgetSetup(name)

        -- Only attach brewing when Heap of Foods is actually present.
        if HAS_HOF then
            local ok = pcall(function()
                inst:AddComponent("brewer")
            end)
            if ok and inst.components.brewer ~= nil then
                MakeBatching(inst)
            end
        end

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(onhammered)
        inst.components.workable:SetOnWorkCallback(onhit)

        inst:AddComponent("hauntable")
        inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

        -- MakeSnowCovered omitted: monkey_barrel / graveurn have no snow symbols.
        MakeLargeBurnable(inst, nil, nil, true)
        MakeLargePropagator(inst)

        return inst
    end

    return Prefab(name, fn, assets),
        MakePlacer(name .. "_placer", bank, build, idleanim)
end

--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- NOTE: a Lua function call in a non-final position is truncated to ONE
-- value, so "return MakeBrewer(a), MakeBrewer(b)" silently drops the first
-- placer. Capture both returns explicitly instead.
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Both use Warly's portable cook pot art, exactly as-is: no tint, no scale
-- change. Only the names differ.
--------------------------------------------------------------------------

local crock, crock_placer = MakeBrewer("bb_saucecrock", "portable_cook_pot", "portable_cook_pot", "idle_empty", nil)

local keg, keg_placer = MakeBrewer("bb_glasskeg", "portable_cook_pot", "portable_cook_pot", "idle_empty", nil)

return crock, crock_placer, keg, keg_placer
