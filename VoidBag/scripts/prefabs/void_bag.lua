-- 实体与网络字段；客户端在SetPristine后返回，服务端才添加组件。装备槽优先BACK，兼容新增背包槽。
local display = require("void_bag_strings")
local core = require("dimension_sorter_core")
local effects = require("void_bag_effects")
local zones = require("void_bag_zones")
local assets = {
    Asset("ANIM", "anim/backpack.zip"),
    Asset("ANIM", "anim/swap_void_bag.zip"),
    Asset("ANIM", "anim/ui_krampusbag_2x8.zip"),
}

local BASE_SLOTS = 14

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("backpack", "swap_void_bag", "backpack")
    owner.AnimState:OverrideSymbol("swap_body", "swap_void_bag", "swap_body")
    if inst._voidbag_zone_migration_blocked then
        display.Notify(owner, "ZONE_FALLBACK")
    end
    if inst.components.container ~= nil then
        inst.components.container:Open(owner)
    end
end

local function onunequip(inst, owner)
    inst._is_space_expanded = false
    owner.AnimState:ClearOverrideSymbol("swap_body")
    owner.AnimState:ClearOverrideSymbol("backpack")
    if inst.components.container ~= nil then
        inst.components.container:Close(owner)
    end
end

local function ondropped(inst)
    inst._is_space_expanded = false
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()
    inst._voidbag_zones = net_bool(inst.GUID, "voidbag.zones")
    inst.entity:AddDynamicShadow()
    inst.DynamicShadow:SetSize(1.25, .7)

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("backpack1")
    inst.AnimState:SetBuild("swap_void_bag")
    inst.AnimState:PlayAnimation("anim")

    inst.MiniMapEntity:SetIcon("void_bag.tex")

    inst:AddTag("backpack")
    inst:AddTag("fridge")
    inst:AddTag("waterproofer")
    inst:AddTag("nosteal")

    MakeInventoryFloatable(inst, "med", 0.1, 0.65, nil, nil, {bank = "backpack1", anim = "anim"})

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._is_space_expanded = false
    inst._voidbag_zones:set(zones.DefaultEnabled())

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.cangoincontainer = false
    inst.foleysound = "dontstarve/movement/foley/krampuspack"
    inst.components.inventoryitem:ChangeImageName("void_bag")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/void_bag.xml"
    inst.components.inventoryitem:SetOnDroppedFn(ondropped)

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BACK or EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(0)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("void_bag")

    local container = inst.components.container
    effects.Attach(inst, container)
    -- Slot policy is configured before WidgetSetup locks widget properties.
    local nativeGive = container.GiveItem
    container._voidbagNativeGive = nativeGive
    container.GiveItem = function(self, item, slot, src_pos, drop_on_fail)
        if slot ~= nil then
            if not zones.Allows(inst, item, slot) then return false end
            if self:GetItemInSlot(slot) == nil then return nativeGive(self, item, slot, src_pos, drop_on_fail) end
            local first, last
            if slot <= BASE_SLOTS then first, last = 1, BASE_SLOTS
            else return core.GiveSlots(self, item, zones.Slots(self, item), src_pos, drop_on_fail) end
            return core.GiveRange(self, item, first, last, src_pos, drop_on_fail)
        end
        return core.GiveRange(self, item, 1, BASE_SLOTS, src_pos, drop_on_fail)
    end
    -- 正式版也需保留：玩家可以更改单元分类，原存档未必满足新规则。
    -- 先完整恢复物品，再预检和重新分区；放不下就临时自由布局，防止丢物。
    -- 这不是测试版名称兼容代码。腾出空间后通过次元校准再次尝试。
    local oldLoad = container.OnLoad
    container.OnLoad = function(self, data, ...)
        local wanted = inst._voidbag_zones:value()
        inst._voidbag_zones:set(false)
        oldLoad(self, data, ...)
        inst._voidbag_zones:set(wanted)
        if wanted then
            if not core.SortVoidBag(self, BASE_SLOTS, false) then
                inst._voidbag_zones:set(false)
                inst._voidbag_zone_migration_blocked = true
            end
        end
    end


    return inst
end

return Prefab("void_bag", fn, assets)
