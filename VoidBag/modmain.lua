-- 入口：注册配方、容器协议、组件钩子、服务器RPC及客户端交互。更改功能前阅读根目录Tellme.txt。
local _G = GLOBAL
local require = _G.require
local Vector3 = _G.Vector3
local Ingredient = _G.Ingredient
local TECH = _G.TECH
local containers = require("containers")
local TheInput = _G.TheInput
local SpacePanel = nil

PrefabFiles = {
    "void_bag",
}

-- 1. 读取配置
local SPACE_CAPACITY = GetModConfigData("SPACE_CAPACITY") or 100
if SPACE_CAPACITY ~= 50 and SPACE_CAPACITY ~= 100 and SPACE_CAPACITY ~= 150 and SPACE_CAPACITY ~= 200 then SPACE_CAPACITY = 100 end
local STACK_FOOD = GetModConfigData("STACK_FOOD")
local SPACE_AUTOPAUSE = GetModConfigData("SPACE_AUTOPAUSE") ~= false
local RECIPE_TECH = GetModConfigData("RECIPE_TECH") or "alchemy"
local RECIPE_DIFF = GetModConfigData("RECIPE_DIFFICULTY") or "easy"
local TOGGLE_KEY = _G["KEY_" .. (GetModConfigData("TOGGLE_KEY") or "X")]
local SORT_MODIFIER = GetModConfigData("SORT_MODIFIER") or "none"
local SORT_KEY = _G["KEY_" .. (GetModConfigData("SORT_KEY") or "J")]
local MERGE_KEY = _G["KEY_" .. (GetModConfigData("MERGE_KEY") or "N")]
local UI_OFFSET_X = 0 -- 屏幕中心锚点；会话内拖动偏移由 void_bag_drag 管理。
local UI_OPACITY = GetModConfigData("UI_OPACITY") or .34

local BASE_SLOTS = 14
local TOTAL_SLOTS = BASE_SLOTS + SPACE_CAPACITY
local BAG_PREFAB = "void_bag"
local function IsBag(inst) return inst and inst.prefab == BAG_PREFAB end

local zones = require("void_bag_zones")
local categories = {}
for i = 1, 8 do categories[i] = GetModConfigData("ZONE_"..i) end
zones.Configure(GetModConfigData("EXCLUSIVE_ZONES"), SPACE_CAPACITY, categories)
local display = require("void_bag_strings")
local dimension_sorter_core = require("dimension_sorter_core")
AddComponentPostInit("inventory", require("void_bag_pickup").Attach)
local bag_effects = require("void_bag_effects")
bag_effects.Configure(GetModConfigData("STACK_MODE") or 0, GetModConfigData("PRESERVATION") or "fridge")

-- Original stack max-size replication only accepts a small fixed enum.
-- Carry the finite 999 limit separately; never feed 999 to the enum encoder.
AddClassPostConstruct("components/stackable_replica", function(self)
    -- 所有客户端固定注册同一网络变量，不按本地开关动态增减协议字段。
    self._voidbag_maxsize = _G.net_ushortint(self.inst.GUID, "voidbag.stackmax")
    local setmax, maxsize = self.SetMaxSize, self.MaxSize
    self.SetMaxSize = function(self, value)
        if value == 999 then self._voidbag_maxsize:set(999)
        else self._voidbag_maxsize:set(0); setmax(self, value) end
    end
    self.MaxSize = function(self)
        local original = maxsize(self)
        if original == math.huge then return original end
        local custom = self._voidbag_maxsize:value()
        return custom > 0 and custom or original
    end
end)

AddComponentPostInit("inventoryitem", function(self)
    local put, removed = self.OnPutInInventory, self.OnRemoved
    self.OnPutInInventory = function(self, owner)
        put(self, owner)
        bag_effects.Enter(self.inst, owner)
    end
    self.OnRemoved = function(self)
        bag_effects.Leave(self.inst)
        return removed(self)
    end
end)


_G.STRINGS.NAMES.VOID_BAG = display.BAG_NAME
_G.STRINGS.RECIPE_DESC.VOID_BAG = display.RECIPE_DESC
_G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.VOID_BAG = _G.string.format(display.INSPECT_FORMAT,
    GetModConfigData("TOGGLE_KEY") or "X", GetModConfigData("MERGE_KEY") or "N")

------------------------------------------------------------------
-- 配方与图标：材料在下方配置，科技独立选择；全局图集登记供生成器等读取。
------------------------------------------------------------------
local ingredients = {}
if RECIPE_DIFF == "easy" then
    ingredients = {
        Ingredient("boards", 10),
        Ingredient("cutstone", 10),
        Ingredient("rope", 10),
        Ingredient("goldnugget", 10),
    }
elseif RECIPE_DIFF == "normal" then
    ingredients = {
        Ingredient("bundlewrap", 1),
        Ingredient("yellowmooneye", 2),
        Ingredient("greenmooneye", 2),
        Ingredient("orangemooneye", 2),
    }
else
    ingredients = {
        Ingredient("opalpreciousgem", 3),
        Ingredient("voidcloth", 9),
        Ingredient("lunarplant_husk", 9),
        Ingredient("alterguardianhatshard", 3),
    }
end

-- Independent atlas with an actual void_bag.tex region.
Assets = { Asset("ATLAS", "images/inventoryimages/void_bag.xml"), Asset("IMAGE", "images/inventoryimages/void_bag.tex") }
local technology = RECIPE_TECH == "magic" and TECH.MAGIC_THREE
    or RECIPE_TECH == "ancient" and TECH.ANCIENT_FOUR
    or RECIPE_TECH == "lunar" and TECH.CELESTIAL_THREE or TECH.SCIENCE_TWO
AddRecipe2(BAG_PREFAB, ingredients, technology, {
    nounlock = RECIPE_TECH == "ancient" or RECIPE_TECH == "lunar",
    atlas = "images/inventoryimages/void_bag.xml",
    image = "void_bag.tex",
}, {"CONTAINERS", "TOOLS", "CLOTHING"})

-- 注册全局图集映射，让 T 键模组也能识别图标

RegisterInventoryItemAtlas("images/inventoryimages/void_bag.xml", "void_bag.tex")
AddMinimapAtlas("images/inventoryimages/void_bag.xml")

------------------------------------------------------------------
-- 容器协议：前14格为外部区，其余按25格单元排列；客户端和服务端一致。
------------------------------------------------------------------
local params = containers.params
local layout = require("void_bag_layout").Create(SPACE_CAPACITY)
params[BAG_PREFAB] = {
    widget = {
        slotpos = {},
        animbank = "ui_krampusbag_2x8",
        animbuild = "ui_krampusbag_2x8",
        pos = Vector3(-5, -120, 0),
    },
    issidewidget = true,
    usespecificslotsforitems = true, -- 必须在 WidgetSetup 前设置，之后是只读属性。
    type = "pack",
    openlimit = 1,
    itemtestfn = function(c, item, slot) return zones.Allows(c.inst, item, slot) end,
}
for y = 0, 6 do
    table.insert(params[BAG_PREFAB].widget.slotpos, Vector3(-162, -75 * y + 240, 0))
    table.insert(params[BAG_PREFAB].widget.slotpos, Vector3(-87, -75 * y + 240, 0))
end
for _, pos in ipairs(layout.slots) do
    table.insert(params[BAG_PREFAB].widget.slotpos, Vector3(pos.x, pos.y, 0))
end

containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, TOTAL_SLOTS)

------------------------------------------------------------------
-- 模块 C：服务端 RPC 注册 (1.次元校准  2.状态同步  3.N键空间吸附)
------------------------------------------------------------------
-- 所有服务器操作共用身份/装备/打开状态校验，不能信任客户端传入实体。
local function ValidBag(player, bag)
    return player ~= nil and player:IsValid() and not player:HasTag("playerghost")
        and bag ~= nil and bag:IsValid() and IsBag(bag)
        and bag.components.container ~= nil and bag.components.container:IsOpenedBy(player)
        and player.components.inventory ~= nil
        and player.components.inventory:GetEquippedItem(_G.EQUIPSLOTS.BACK or _G.EQUIPSLOTS.BODY) == bag
end

AddModRPCHandler("VoidBagRPC", "StoreSlot", function(player, bag, slot)
    if not ValidBag(player, bag) or not bag._is_space_expanded then return end
    if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1
        or slot > player.components.inventory.maxslots then return end
    dimension_sorter_core.StoreInventorySlot(player, bag.components.container, slot, BASE_SLOTS)
end)

AddModRPCHandler("VoidBagRPC", "StoreExterior", function(player, bag, slot)
    if not ValidBag(player, bag) or not bag._is_space_expanded then return end
    if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > BASE_SLOTS then return end
    dimension_sorter_core.StoreExteriorSlot(bag.components.container, slot)
end)

-- RPC 1: 执行次元校准
AddModRPCHandler("VoidBagRPC", "SortSpace", function(player, bag_inst)
    if not ValidBag(player, bag_inst) then return end

    local retry = bag_inst._voidbag_zone_migration_blocked
    if retry then bag_inst._voidbag_zones:set(true) end
    local sorted = dimension_sorter_core.SortVoidBag(bag_inst.components.container, BASE_SLOTS, STACK_FOOD)
    if not sorted then
        if retry then bag_inst._voidbag_zones:set(false) end
        display.Notify(player, "ZONE_FULL")
    else
        bag_inst._voidbag_zone_migration_blocked = nil
    end
end)

-- RPC 2: 同步客户端次元维度“展开/收起”状态到服务端
AddModRPCHandler("VoidBagRPC", "SyncExpanded", function(player, bag_inst, is_expanded)
    if not ValidBag(player, bag_inst) then return end
    bag_inst._is_space_expanded = (is_expanded == true)
end)

-- RPC 3: 身体与外部14格按内部已有种类吸附，包含普通食物和蛋类。
AddModRPCHandler("VoidBagRPC", "ManualMerge", function(player, bag_inst)
    if not ValidBag(player, bag_inst) then return end

    local count = dimension_sorter_core.MergeInventoryToSpace(player, bag_inst.components.container, BASE_SLOTS)
    display.Notify(player, count > 0 and "MERGE_SUCCESS" or "MERGE_EMPTY", count)
end)

------------------------------------------------------------------
-- 模块 D：客户端半透明黑底板、双按钮与空间折叠控制
------------------------------------------------------------------
-- 必须在专用服务器return前登记客户端RPC，双方ID表保持一致。
AddClientModRPCHandler("VoidBagRPC", "Notice", function(key, count)
    if key ~= "ZONE_FULL" and key ~= "ZONE_FALLBACK" and key ~= "MERGE_SUCCESS" and key ~= "MERGE_EMPTY" then return end
    local player = _G.ThePlayer
    if player and player.components.talker then
        local message = key == "MERGE_SUCCESS" and _G.string.format(display[key], count) or display[key]
        player.components.talker:Say(message)
    end
end)
if _G.TheNet:IsDedicated() then return end
SpacePanel = require("widgets/voidbag_space_panel")
local is_space_expanded = false
local owns_autopause = false
-- 只配对释放本面板持有的官方暂停计数，不解除菜单/其他模组的暂停。
local function UpdateAutopause(open)
    local wanted = open and SPACE_AUTOPAUSE
    if wanted ~= owns_autopause then
        owns_autopause = wanted
        _G.SetAutopaused(wanted)
    end
end

local function SyncExpandedToServer(bag_inst)
    if bag_inst then
        _G.SendModRPCToServer(_G.GetModRPC("VoidBagRPC", "SyncExpanded"), bag_inst, is_space_expanded)
    end
end

local function UpdateMysterySpaceUI(self)
    UpdateAutopause(is_space_expanded)
    if self and self.voidbag_panel then
        if is_space_expanded then
            self.voidbag_panel:Show()
            self.voidbag_panel:RefreshLayout()
        else
            self.voidbag_panel:Hide()
        end
    end
end

local ApplyBagLayout
AddClassPostConstruct("widgets/containerwidget", function(self)
    local old_Open = self.Open
    self.Open = function(self, container_inst, doer)
        if IsBag(container_inst) then
            local controls = self.owner and self.owner.HUD and self.owner.HUD.controls
            local previous = controls and controls.containers and controls.containers[container_inst]
            if previous and previous ~= self then
                -- RefreshControllers直接调用原版局部OpenContainerWidget，绕过HUD.OpenContainer。
                -- 在共同创建入口交接所有权，不能等登记表被新窗口覆盖后再清理旧窗口。
                controls.containers[container_inst] = nil
                previous:Close()
                previous:Hide()
                previous:Kill()
            end
        end
        old_Open(self, container_inst, doer)
        if container_inst and IsBag(container_inst) then
            is_space_expanded = false
            local controls = self.owner and self.owner.HUD and self.owner.HUD.controls
            if not controls or not controls.containerroot then return end
            local function send(action)
                _G.SendModRPCToServer(_G.GetModRPC("VoidBagRPC", action), container_inst)
            end
            self.voidbag_panel = controls.containerroot:AddChild(SpacePanel(require("void_bag_layout").Create(SPACE_CAPACITY, zones.IsEnabled(container_inst)), UI_OFFSET_X, UI_OPACITY,
                function() send("SortSpace") end,
                function() send("ManualMerge") end,
                function()
                    is_space_expanded = false
                    UpdateMysterySpaceUI(self)
                    SyncExpandedToServer(container_inst)
                end))
            for i = BASE_SLOTS + 1, TOTAL_SLOTS do
                if self.inv[i] then
                    self.voidbag_panel:AddChild(self.inv[i])
                    local pos = self.voidbag_panel.layout.slots[i - BASE_SLOTS]
                    self.inv[i]:SetPosition(pos.x, pos.y, 0)
                end
            end
            UpdateMysterySpaceUI(self)
            SyncExpandedToServer(container_inst)
            -- 包括由原版设置切换直接创建的窗口，立即应用当前布局。
            controls.containers[container_inst] = self
            ApplyBagLayout(self)
        end
    end
    local old_Close = self.Close
    self.Close = function(self)
        if self.container and IsBag(self.container) then is_space_expanded = false; UpdateAutopause(false) end
        -- Let the stock widget dispose its slots first, even when reparented.
        old_Close(self)
        if self.voidbag_panel then self.voidbag_panel:Kill(); self.voidbag_panel = nil end
    end
end)

-- 官方融合布局只绘制外部14格，内部槽仍由独立面板管理。
-- UI不是打开状态的来源：联机客户端GetOpenContainers会读取可见Widget，不能用于清理判断。
local function IntegratedBagLayout()
    return TheInput:ControllerAttached() or (_G.Profile and _G.Profile:GetIntegratedBackpack())
end
ApplyBagLayout = function(widget)
    local integrated = IntegratedBagLayout()
    for i = 1, BASE_SLOTS do
        local slot = widget.inv[i]
        if slot then if integrated then slot:Hide() else slot:Show() end end
    end
    if integrated then widget.bganim:Hide(); widget.bgimage:Hide()
    elseif widget.bgimage.texture then widget.bgimage:Show()
    else widget.bganim:Show() end
end
local function DisposeBagWidget(hud, bag)
    local controls = hud.controls
    local widget = controls and controls.containers and controls.containers[bag]
    if not widget then return end
    -- 先从登记表移除，避免其他更新路径再访问已经关闭的槽位。
    controls.containers[bag] = nil
    widget:Close()
    widget:Hide()
    widget:Kill()
    if controls.inv then controls.inv.rebuild_pending = true end
end
local function EnsureBagWidget(hud, bag)
    local controls = hud.controls
    local existing = controls and controls.containers and controls.containers[bag]
    if existing and existing.container == bag then ApplyBagLayout(existing); return end
    if not controls or not controls.containers then return end
    local parent = controls.containerroot_side or controls.containerroot
    if not parent then return end
    -- 已关闭的旧窗口需销毁，避免设置切换/重新装备累积空Widget。
    if existing then
        controls.containers[bag] = nil
        existing:Hide()
        existing:Kill()
    end
    local ContainerWidget = require("widgets/containerwidget")
    local widget = parent:AddChild(ContainerWidget(hud.owner))
    widget:MoveToBack()
    widget:Open(bag, hud.owner)
    controls.containers[bag] = widget
    ApplyBagLayout(widget)
    if controls.inv and controls.inv.OnNewContainerWidget then controls.inv:OnNewContainerWidget(widget) end
end
AddClassPostConstruct("screens/playerhud", function(self)
    self._voidbag_closed = {}
    local open, close, update = self.OpenContainer, self.CloseContainer, self.OnUpdate
    self.OpenContainer = function(self, container, side)
        if IsBag(container) then
            self._voidbag_closed[container] = nil
            EnsureBagWidget(self, container)
            if self.controls.inv then self.controls.inv.rebuild_pending = true end
            return
        end
        return open(self, container, side)
    end
    self.CloseContainer = function(self, container, side)
        if IsBag(container) then
            -- 明确关闭事件优先于可能晚一帧更新的容器打开网络状态。
            self._voidbag_closed[container] = true
            DisposeBagWidget(self, container)
            return
        end
        return close(self, container, side)
    end
    self.OnUpdate = function(self, dt)
        update(self, dt)
        -- PushScreen会在SetMainCharacter/Controls创建前立即更新HUD(dt=0)。
        -- 与原版一样等待界面就绪；加载、切世界和销毁期间都不访问未创建的控件。
        if not self.controls or not self.controls.containers then return end
        -- 同时检查装备归属与真实打开状态，防止丢弃后可见UI自我维持。
        local inventory = self.owner and self.owner.replica and self.owner.replica.inventory
        if not inventory then return end
        local equipped = inventory and inventory:GetEquippedItem(_G.EQUIPSLOTS.BACK or _G.EQUIPSLOTS.BODY)
        local bag = IsBag(equipped) and equipped or nil
        local active = bag and bag:IsValid() and bag.replica.container
            and bag.replica.container:IsOpenedBy(self.owner) and not self._voidbag_closed[bag]
        local stale = {}
        for inst in pairs(self.controls.containers) do
            if IsBag(inst) and (inst ~= bag or not active) then stale[#stale + 1] = inst end
        end
        for _, inst in ipairs(stale) do DisposeBagWidget(self, inst) end
        for inst in pairs(self._voidbag_closed) do
            if inst ~= bag then self._voidbag_closed[inst] = nil end
        end
        -- 设置/控制器切换会绕过HUD方法直接关窗口；只补建仍归属本人且打开的袋子。
        if active then EnsureBagWidget(self, bag) end
    end
end)
AddClassPostConstruct("widgets/inventorybar", function(self)
    local rebuild = self.Rebuild
    self.Rebuild = function(self, ...)
        local inventory = self.owner and self.owner.replica.inventory
        local overflow = inventory and inventory:GetOverflowContainer()
        if not overflow or not IsBag(overflow.inst) then return rebuild(self, ...) end
        -- 只在同步布局调用内限制枚举数量；InvSlot保留真实容器，RPC/容量/物品数据不变。
        -- rawget用于恢复原有继承关系，避免永久给实例添加影子方法。
        local own = _G.rawget(overflow, "GetNumSlots")
        overflow.GetNumSlots = function() return BASE_SLOTS end
        local ok, result = _G.pcall(rebuild, self, ...)
        overflow.GetNumSlots = own
        if not ok then _G.error(result) end
        return result
    end
    -- 内部槽也会发itemget/itemlose，融合栏没有这些槽，避免把nil传给其他模组包装。
    local get, lose = self.OnItemGet, self.OnItemLose
    self.OnItemGet = function(self, item, slot, ...)
        if IsBag(self.backpack) and slot == nil then return end
        return get(self, item, slot, ...)
    end
    self.OnItemLose = function(self, slot, ...)
        if IsBag(self.backpack) and slot == nil then return end
        return lose(self, slot, ...)
    end
end)

local function IsPlayerTyping(player)
    if not player or not player.HUD then return true end
    return player.HUD:HasInputFocus()
end

local function GetOpenedVoidBag(player)
    local open_containers = player.replica.inventory and player.replica.inventory:GetOpenContainers()
    if open_containers then
        for container_inst, _ in pairs(open_containers) do
            if container_inst and IsBag(container_inst) then
                return container_inst
            end
        end
    end
    return nil
end

-- 1. 按 X 键切换次元维度展开/收起
TheInput:AddKeyUpHandler(TOGGLE_KEY, function()
    local player = _G.ThePlayer
    if (_G.IsPaused() and not owns_autopause) or IsPlayerTyping(player) then return end
    if not player.HUD.controls then return end

    if not GetOpenedVoidBag(player) then return end
    is_space_expanded = not is_space_expanded
    local containers_ui = player.HUD.controls.containers
    if containers_ui then
        for container_inst, widget in pairs(containers_ui) do
            if container_inst and IsBag(container_inst) then
                UpdateMysterySpaceUI(widget)
                SyncExpandedToServer(container_inst)
                if player.SoundEmitter then
                    player.SoundEmitter:PlaySound("dontstarve/HUD/craft_open")
                end
            end
        end
    end
end)

-- 2. 按配置的快捷键及组合键触发次元校准
TheInput:AddKeyUpHandler(SORT_KEY, function()
    local player = _G.ThePlayer
    if (_G.IsPaused() and not owns_autopause) or IsPlayerTyping(player) then return end
    if SORT_MODIFIER == "shift" and not TheInput:IsKeyDown(_G.KEY_SHIFT) then return end
    if SORT_MODIFIER == "ctrl" and not TheInput:IsKeyDown(_G.KEY_CTRL) then return end

    local bag_inst = GetOpenedVoidBag(player)
    if bag_inst then
        _G.SendModRPCToServer(_G.GetModRPC("VoidBagRPC", "SortSpace"), bag_inst)
        if player.SoundEmitter then
            player.SoundEmitter:PlaySound("dontstarve/HUD/craft_down")
        end
    end
end)

-- 3. 按配置的快捷键触发空间吸附
TheInput:AddKeyUpHandler(MERGE_KEY, function()
    local player = _G.ThePlayer
    if (_G.IsPaused() and not owns_autopause) or IsPlayerTyping(player) then return end

    local bag_inst = GetOpenedVoidBag(player)
    if bag_inst then
        _G.SendModRPCToServer(_G.GetModRPC("VoidBagRPC", "ManualMerge"), bag_inst)
        if player.SoundEmitter then
            player.SoundEmitter:PlaySound("dontstarve/HUD/craft_down")
        end
    end
end)
-- Route Shift-click from player pockets directly through a validated server RPC.
AddClassPostConstruct("widgets/invslot", function(self)
    local old = self.OnControl
    self.OnControl = function(self, control, down)
        local player = _G.ThePlayer
        if down and control == _G.CONTROL_ACCEPT and is_space_expanded
            and player ~= nil and self.owner == player
            and TheInput:IsKeyDown(_G.KEY_SHIFT) and not IsPlayerTyping(player) then
            local bag = GetOpenedVoidBag(player)
            local exterior = bag and self.container == bag.replica.container and self.num <= BASE_SLOTS
            if bag ~= nil and (exterior or self.container == player.replica.inventory) then
                _G.SendModRPCToServer(_G.GetModRPC("VoidBagRPC", exterior and "StoreExterior" or "StoreSlot"), bag, self.num)
                return true
            end
        end
        return old(self, control, down)
    end
end)
