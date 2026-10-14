-- 只在原生拾取选择器调用期间提供14格只读视图，防止采集/拾取自动进入隐藏空间；不改实际槽位。
-- A bounded READ VIEW of the overflow container, used only while inventory
-- calculates pickup slots/capacity. The real slots and network state stay intact.
local Pickup = {}
local function exterior(c)
    local view = { slots = {}, numslots = 14, inst = c.inst }
    for i = 1, 14 do view.slots[i] = c.slots[i] end
    function view:GetNumSlots() return 14 end
    function view:ShouldPrioritizeContainer() return false end
    setmetatable(view, { __index = function(_, key)
        local value = c[key]
        if type(value) == "function" then return function(_, ...) return value(c, ...) end end
        return value
    end })
    return view
end

function Pickup.Attach(inventory)
    for _, name in ipairs({ "GetNextAvailableSlot", "CanAcceptCount" }) do
        local original = inventory[name]
        inventory[name] = function(self, ...)
            local get = self.GetOverflowContainer
            local actual = get(self)
            if not actual or actual.inst.prefab ~= "void_bag" then return original(self, ...) end
            local view = exterior(actual)
            self.GetOverflowContainer = function() return view end
            local ok, value, container = pcall(original, self, ...)
            self.GetOverflowContainer = get
            if not ok then error(value) end
            if container == view then container = actual end
            return value, container
        end
    end
end

return Pickup
