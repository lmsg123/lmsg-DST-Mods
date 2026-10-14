-- 袋内堆叠与保鲜：离袋恢复原倍率；大堆叠在公开取物入口拆分，禁止在底层移除时偷偷返回部分实体。
local Effects = {}
local settings = { stack = 0, preservation = "fridge" }

function Effects.Configure(stack, preservation)
    settings.stack = stack == 999 and 999 or 0
    settings.preservation = preservation or "fridge"
end

local function PerishRate(item)
    if settings.preservation == "permanent" then return 0 end
    local rate = item:HasTag("frozen") and TUNING.PERISH_COLD_FROZEN_MULT or TUNING.PERISH_FRIDGE_MULT
    return settings.preservation == "triple" and rate / 3 or rate
end
function Effects.Enter(item, owner)
    if not owner or owner.prefab ~= "void_bag" then return end
    Effects.PrepareStack(item)
    local p = item.components.perishable
    if p then
        if item._voidbag_perish_original == nil then item._voidbag_perish_original = p:GetLocalMultiplier() end
        p:SetLocalMultiplier(item._voidbag_perish_original * PerishRate(item))
    end
end

function Effects.PrepareStack(item)
    local s = item.components.stackable
    if s and settings.stack == 999 and not s.originalmaxsize then
        if item._voidbag_stack_original == nil then item._voidbag_stack_original = s.maxsize end
        s.maxsize = 999
    end
end

function Effects.Leave(item)
    local s, p = item.components.stackable, item.components.perishable
    if s and item._voidbag_stack_original ~= nil then
        s.maxsize = item._voidbag_stack_original
        item._voidbag_stack_original = nil
    end
    if p and item._voidbag_perish_original ~= nil then
        p:SetLocalMultiplier(item._voidbag_perish_original)
        item._voidbag_perish_original = nil
    end
end

function Effects.Attach(inst, container)
    inst:AddTag("fridge")
    inst:AddComponent("preserver")
    inst.components.preserver:SetPerishRateMultiplier(function(_, item)
        -- All perishable components (including hats and live fish) receive the
        -- local multiplier on insertion. Do not apply the same factor twice.
        return item._voidbag_perish_original ~= nil and 1 or PerishRate(item)
    end)
    -- Bound cursor withdrawals at the public action boundary. Native click
    -- handlers may discard RemoveItemBySlot's return value, so splitting inside
    -- RemoveItem_Internal would give the SAME entity to both slot and cursor.
    local function limit(self, slot)
        local item = self:GetItemInSlot(slot)
        local stack = item and item.components.stackable
        local original = item and item._voidbag_stack_original
        return stack and original and stack:StackSize() > original and original or nil
    end
    local takeAll = container.TakeActiveItemFromAllOfSlot
    local takeHalf = container.TakeActiveItemFromHalfOfSlot
    local takeCount = container.TakeActiveItemFromCountOfSlot
    container.TakeActiveItemFromAllOfSlot = function(self, slot, opener)
        local maximum = limit(self, slot)
        if maximum then return takeCount(self, slot, maximum, opener) end
        return takeAll(self, slot, opener)
    end
    container.TakeActiveItemFromHalfOfSlot = function(self, slot, opener)
        local maximum = limit(self, slot)
        if maximum then return takeCount(self, slot, math.max(1, math.floor(maximum / 2)), opener) end
        return takeHalf(self, slot, opener)
    end
    container.TakeActiveItemFromCountOfSlot = function(self, slot, count, opener)
        local maximum = limit(self, slot)
        return takeCount(self, slot, maximum and math.min(count, maximum) or count, opener)
    end
    -- The vanilla swap action assumes a single removable stack; disallow an
    -- oversized swap until it has been withdrawn in normal-size portions.
    for _, action in ipairs({"SwapActiveItemWithSlot", "SwapOneOfActiveItemWithSlot"}) do
        local original = container[action]
        container[action] = function(self, slot, opener)
            if limit(self, slot) then return end
            return original(self, slot, opener)
        end
    end
    local nativeDrop = container.DropItemBySlot
    container.DropItemBySlot = function(self, slot, ...)
        local previous = self._voidbag_reorganizing
        self._voidbag_reorganizing = true
        local item = nativeDrop(self, slot, ...)
        self._voidbag_reorganizing = previous
        local stack = item and item.components.stackable
        while stack and stack:StackSize() > stack.maxsize do
            local excess = stack:Get(stack.maxsize)
            excess.Transform:SetPosition(item.Transform:GetWorldPosition())
            excess.components.inventoryitem:OnDropped(true)
        end
        return item
    end
end

return Effects
