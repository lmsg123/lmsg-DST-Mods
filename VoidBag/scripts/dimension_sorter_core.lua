-- 仅服务端执行：分类/耐久排序、局部堆叠、同类吸附。必须走原生容器生命周期，不直接写 slots。
local dimension_sorter_core = {}
local effects = require("void_bag_effects")
local zones = require("void_bag_zones")

-- 宝石排序字典：1红 -> 2蓝 -> 3紫 -> 4黄 -> 5绿 -> 6橙 -> 7彩虹
local GEM_ORDER = {
    redgem = 1,
    bluegem = 2,
    purplegem = 3,
    yellowgem = 4,
    greengem = 5,
    orangegem = 6,
    opalpreciousgem = 7,
}

-- 判断物品是否属于食物或可腐烂物（排除火腿棒等武器）
local function IsFoodOrPerishable(item)
    if not item or not item.components then return false end
    if item.components.weapon ~= nil then return false end
    return (zones.Category(item) == 4 or item.components.perishable ~= nil)
end

-- 获取物品的精确耐久度或新鲜度百分比 (0.0 ~ 1.0)
local function GetItemPercent(item)
    if not item or not item.components then return 1 end
    local comps = item.components
    if comps.finiteuses then
        return comps.finiteuses:GetPercent() or 1
    elseif comps.armor then
        return comps.armor:GetPercent() or 1
    elseif comps.fueled then
        return comps.fueled:GetPercent() or 1
    elseif comps.perishable then
        return comps.perishable:GetPercent() or 1
    end
    return 1
end

-- 获取物品的大类编号 (1~7)
local function GetItemCategory(item)
    if not item or not item.components then return 99 end
    local comps = item.components
    local prefab = item.prefab or ""

    -- 1. 宝石最高优拦截（防止任何模组给宝石加奇怪组件导致宝石掉进材料堆！）
    if GEM_ORDER[prefab] then
        return 6 -- 宝石固定为第 6 大类
    end

    -- 分区与排序共用主要用途规则；能攻击的锄头/船桨/手杖仍先算工具。
    local category = zones.Category(item)
    if category == 1 then return 2 end
    if category == 2 then return comps.armor and 3 or 1 end
    if category == 3 then return 4 end
    if category == 4 or comps.perishable then return 5 end
    return 7

end

-- 严格排序比较器
local function CompareItems(a, b)
    if a == b then return false end
    local catA = GetItemCategory(a)
    local catB = GetItemCategory(b)

    -- 第一层：大类不同，按 1武器 -> 2工具 -> 3护甲 -> 4服装 -> 5食物 -> 6宝石 -> 7材料 排序
    if catA ~= catB then
        return catA < catB
    end

    local prefabA = a.prefab or ""
    local prefabB = b.prefab or ""

    -- 第二层：大类内部精细排序
    if catA == 6 then
        -- 【宝石类】：严格按照 红(1) -> 蓝(2) -> 紫(3) -> 黄(4) -> 绿(5) -> 橙(6) -> 彩虹(7) 排序！
        local gemA = GEM_ORDER[prefabA] or 99
        local gemB = GEM_ORDER[prefabB] or 99
        if gemA ~= gemB then
            return gemA < gemB
        end

    elseif catA == 1 then
        -- 【武器类】：先按伤害从高到低；同伤害按代码名聚类；同名武器按耐久从高到低！
        local dmgA = (a.components.weapon and type(a.components.weapon.damage) == "number") and a.components.weapon.damage or 0
        local dmgB = (b.components.weapon and type(b.components.weapon.damage) == "number") and b.components.weapon.damage or 0
        if math.abs(dmgA - dmgB) > 0.01 then
            return dmgA > dmgB
        end
        if prefabA ~= prefabB then
            return prefabA < prefabB
        end
        local pctA, pctB = GetItemPercent(a), GetItemPercent(b)
        if math.abs(pctA - pctB) > 0.0001 then
            return pctA > pctB
        end

    elseif catA >= 2 and catA <= 5 then
        -- 【工具、护甲、服装、食物】：
        -- 先按物品种类聚类（比如鹤嘴锄和鹤嘴锄挨着，斧头和斧头挨着，大肉和大肉挨着），
        -- 同一种物品内部，严格按耐久度/新鲜度从高到低 (100% -> 73% -> 39%) 降序排列！
        if prefabA ~= prefabB then
            return prefabA < prefabB
        end
        local pctA, pctB = GetItemPercent(a), GetItemPercent(b)
        if math.abs(pctA - pctB) > 0.0001 then
            return pctA > pctB
        end

    else
        -- 【普通材料类】：按代码名 A-Z 聚类
        if prefabA ~= prefabB then
            return prefabA < prefabB
        end
    end

    -- 第三层：同名同属性物品，堆叠数量多的排前面
    local stackA = (a.components.stackable and a.components.stackable:StackSize()) or 1
    local stackB = (b.components.stackable and b.components.stackable:StackSize()) or 1
    if stackA ~= stackB then
        return stackA > stackB
    end

    return (a.GUID or 0) < (b.GUID or 0)
end


-- Merge only within the selected range. Native GiveItem receives an EMPTY slot,
-- so it neither merges food elsewhere nor searches across the exterior boundary.
function dimension_sorter_core.GiveSlots(c, item, slots, pos, drop)
    if item == nil then return false end
    if not c:CanTakeItemInSlot(item, nil) then return false end
    if item.components.stackable then
        for _, slot in ipairs(slots) do
            local other = c:GetItemInSlot(slot)
            if other and other.components.stackable
                and item.components.stackable:CanStackWith(other)
                and not other.components.stackable:IsFull() then
                item = other.components.stackable:Put(item, pos)
                if item == nil then return true end
            end
        end
    end
    for _, slot in ipairs(slots) do
        if c:GetItemInSlot(slot) == nil and c:CanTakeItemInSlot(item, slot) then
            return c._voidbagNativeGive(c, item, slot, pos, drop)
        end
    end
    if drop ~= false then
        item.Transform:SetPosition(c.inst.Transform:GetWorldPosition())
        item.components.inventoryitem:OnDropped(true)
    end
    return false
end

function dimension_sorter_core.GiveRange(c, item, first, last, pos, drop)
    local slots = {}
    for slot = first, last do slots[#slots+1] = slot end
    return dimension_sorter_core.GiveSlots(c, item, slots, pos, drop)
end

function dimension_sorter_core.SortVoidBag(c, base, stack_food)
    if not c then return end
    local first, last = (base or 14) + 1, c:GetNumSlots()
    local existing = {}
    for slot = first, last do
        local item = c:GetItemInSlot(slot)
        if item then
            if not c:CanTakeItemInSlot(item, nil) then return false end
            existing[#existing + 1] = item
        end
    end
    if not zones.CanRouteItems(c, existing) then return false end
    local items = {}
    c._voidbag_reorganizing = true
    for slot = first, last do
        local item = c:RemoveItemBySlot(slot)
        if item then effects.PrepareStack(item); items[#items + 1] = item end
    end
    local merged = {}
    for _, original in ipairs(items) do
        local item = original
        if item.components.stackable and (stack_food or not IsFoodOrPerishable(item)) then
            for _, other in ipairs(merged) do
                if other.components.stackable and item.components.stackable:CanStackWith(other)
                    and not other.components.stackable:IsFull() then
                    item = other.components.stackable:Put(item)
                    if item == nil then break end
                end
            end
        end
        if item then merged[#merged + 1] = item end
    end
    table.sort(merged, CompareItems)
    local targets = zones.Plan(c, merged)
    for index, item in ipairs(merged) do
        local target = targets and targets[index]
        if not target or not c._voidbagNativeGive(c, item, target, nil, false) then
            item.Transform:SetPosition(c.inst.Transform:GetWorldPosition())
            item.components.inventoryitem:OnDropped(true)
        end
    end
    c._voidbag_reorganizing = nil
    return true
end

function dimension_sorter_core.StoreInventorySlot(player, c, slot, base)
    local inv = player.components.inventory
    local item = inv:GetItemInSlot(slot)
    if item == nil or item.components.inventoryitem == nil
        or item.components.inventoryitem.islockedinslot
        or not c:CanTakeItemInSlot(item, nil) then return false end
    local before = item.components.stackable and item.components.stackable:StackSize() or 1
    item = inv:RemoveItemBySlot(slot)
    if item == nil then return false end
    local ok = dimension_sorter_core.GiveSlots(c, item, zones.Slots(c, item), nil, false)
    if ok then return true end
    local after = item.components.stackable and item.components.stackable:StackSize() or 1
    inv:GiveItem(item, slot)
    return after < before
end

function dimension_sorter_core.MergeInventoryToSpace(player, c, base)
    if not player or not player.components.inventory or not c then return 0 end
    local inv, count = player.components.inventory, 0
    -- Snapshot the seed types BEFORE transferring; exterior slots never seed N.
    local existing = {}
    for slot = (base or 14) + 1, c:GetNumSlots() do
        local other = c:GetItemInSlot(slot)
        if other then existing[other.prefab] = true end
    end
    for slot = 1, inv.maxslots do
        local item = inv:GetItemInSlot(slot)
        if item and existing[item.prefab] and (item.components.stackable or zones.CanArchiveUnstackable(item)) then
            if dimension_sorter_core.StoreInventorySlot(player, c, slot, base) then count = count + 1 end
        end
    end
    for slot = 1, base or 14 do
        local item = c:GetItemInSlot(slot)
        if item and existing[item.prefab] and (item.components.stackable or zones.CanArchiveUnstackable(item)) then
            if dimension_sorter_core.StoreExteriorSlot(c, slot) then count = count + 1 end
        end
    end
    return count
end

function dimension_sorter_core.StoreExteriorSlot(c, slot)
    local item = c:GetItemInSlot(slot)
    if not item or not item.components.inventoryitem or item.components.inventoryitem.islockedinslot then return false end
    local before = item.components.stackable and item.components.stackable:StackSize() or 1
    item = c:RemoveItemBySlot(slot)
    if not item then return false end
    local ok = dimension_sorter_core.GiveSlots(c, item, zones.Slots(c, item), nil, false)
    if not ok then c._voidbagNativeGive(c, item, slot, nil, true) end
    return ok or (item.components.stackable and item.components.stackable:StackSize() < before) or false
end
return dimension_sorter_core
