-- 客户端/服务端共享分类规则：专属槽优先、通用槽兜底；Plan预留专属槽后分配溢出，避免材料占用配额。
local Zones = {}
local enabled = false
local defaults = {1, 2, 3, 4, 0, 0, 0, 0}
local types = defaults
local titles = require("void_bag_strings").ZONE_TITLES
local names = {}
for i = 1, 8 do names[i] = titles[defaults[i]] end

function Zones.Configure(value, capacity, configured)
    enabled = value == true
    types, names = {}, {}
    for i = 1, 8 do
        local v = configured and configured[i] or defaults[i]
        types[i] = titles[v] and v or 0
        names[i] = titles[types[i]]
    end
end
function Zones.IsEnabled(inst)
    return inst and inst._voidbag_zones and inst._voidbag_zones:value() or false
end
function Zones.DefaultEnabled() return enabled end
function Zones.Names() return names end
local icons = {[0]="filter_containers.tex", "filter_tool.tex", "filter_weapon.tex", "filter_warable.tex", "filter_cooking.tex"}
function Zones.Icon(i) return icons[types[i] or 0] end

local function tagged(item, tag)
    return item.HasTag and item:HasTag(tag) or false
end

-- 原生weapon表示能攻击，不代表主要用途；以下原生功能道具缺少通用tool组件。
-- 客户端也按prefab判断，避免服务端组件与客户端标签分类不同。
local utility_tools = {
    cane=true, farm_hoe=true, golden_farm_hoe=true, pitchfork=true,
    oar=true, oar_driftwood=true, oar_monkey=true, malbatross_beak=true, yotd_oar=true,
    fishingrod=true, oceanfishingrod=true, wateringcan=true, premiumwateringcan=true,
    brush=true, razor=true, sewing_kit=true, saddlehorn=true, compass=true,
    torch=true, lantern=true, mininglantern=true,
    orangestaff=true, telestaff=true, greenstaff=true, yellowstaff=true,
}
function Zones.IsTool(item)
    local c = item.components or {}
    return utility_tools[item.prefab] == true or c.tool ~= nil or tagged(item, "tool")
        or tagged(item, "oar") or tagged(item, "fishingrod") or tagged(item, "wateringcan")
end

function Zones.Category(item)
    local c = item.components or {}
    if Zones.IsTool(item) then return 1 end
    -- 雨伞首先是穿戴防护；其他装备仍按护甲/武器/普通穿戴顺序判断。
    if tagged(item, "umbrella") then return 3 end
    if c.weapon or c.armor or tagged(item, "weapon") or tagged(item, "armor") then return 2 end
    if c.equippable or (item.replica and item.replica.equippable) then return 3 end
    -- Mole/Woodie/WX-only edible materials stay in the materials section.
    local foodtype = c.edible and c.edible.foodtype
    if foodtype == "MEAT" or foodtype == "VEGGIE" or foodtype == "GENERIC" or foodtype == "GOODIES" or foodtype == "SEEDS"
        or tagged(item, "edible_MEAT") or tagged(item, "edible_VEGGIE")
        or tagged(item, "edible_GENERIC") or tagged(item, "edible_GOODIES") or tagged(item, "edible_SEEDS") then return 4 end
    return 5
end

function Zones.Allows(inst, item, slot)
    if not slot or slot <= 14 or not Zones.IsEnabled(inst) then return true end
    local kind = types[math.floor((slot - 15) / 25) + 1] or 0
    return kind == 0 or kind == Zones.Category(item)
end
function Zones.Slots(c, item)
    local result = {}
    if not Zones.IsEnabled(c.inst) then
        for slot = 15, c:GetNumSlots() do result[#result+1] = slot end
    else
        local category = Zones.Category(item)
        for _, kind in ipairs({category, 0}) do
            for slot = 15, c:GetNumSlots() do
                if (types[math.floor((slot-15)/25)+1] or 0) == kind then result[#result+1] = slot end
            end
        end
    end
    return result
end
function Zones.Plan(c, items)
    local occupied, targets = {}, {}
    -- Reserve specialist slots before allowing any overflow into universal slots.
    for i, item in ipairs(items) do
        for _, slot in ipairs(Zones.Slots(c, item)) do
            local kind = types[math.floor((slot-15)/25)+1] or 0
            if not occupied[slot] and (not Zones.IsEnabled(c.inst) or kind ~= 0) and c:CanTakeItemInSlot(item, slot) then
                targets[i], occupied[slot] = slot, true; break
            end
        end
    end
    for i, item in ipairs(items) do
        if not targets[i] then
            for _, slot in ipairs(Zones.Slots(c, item)) do
                if not occupied[slot] and c:CanTakeItemInSlot(item, slot) then targets[i], occupied[slot] = slot, true; break end
            end
            if not targets[i] then return nil end
        end
    end
    return targets
end
function Zones.CanRouteItems(c, items) return Zones.Plan(c, items) ~= nil end

function Zones.CanArchiveUnstackable(item)
    local c = item.components or {}
    return not (Zones.IsTool(item) or c.weapon or c.armor or c.equippable)
end

return Zones
