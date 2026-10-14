-- modinfo受限环境提供locale；此函数只用Lua基本语法，不依赖table/require/GLOBAL。
local is_zh = locale == "zh" or locale == "zht" or locale == "zhr"
local function T(zh, en) return is_zh and zh or en end
-- 配置元数据在受限环境执行，不能使用 require、table、GLOBAL 等游戏/标准库；保持静态声明。
name = T("Void Bag [虚空袋]", "Void Bag")
description = T("14格外部常用区与可折叠次元维度。次元校准、空间吸附、分区管理与袋内保鲜。", "14 exterior slots and a foldable dimension. Sorting, matching-item transfer, zones and preservation.")
author = "lmsg"
version = "1.0.6"
icon_atlas = "modicon.xml"
icon = "modicon.tex"
-- 尽量在改写堆叠构造器的模组之后安装包装；否则其整段_ctor替换会抹掉网络适配。
priority = -10000
api_version = 10
dst_compatible = true
client_only_mod = false
all_clients_require_mod = true
configuration_options = {
    {
        hover = T("展开次元维度时请求官方自动暂停；需在游戏设置开启自动暂停，多人在线时遵循官方规则。", "Requests official auto-pause. Enable auto-pause in game settings; multiplayer follows the game rules."),
        name = "SPACE_AUTOPAUSE",
        label = T("单人打开空间时暂停", "Auto-pause when opened"),
        default = true,
        options = {
            {
                description = T("开启", "Enabled"),
                data = true,
            },
            {
                description = T("关闭", "Disabled"),
                data = false,
            },
        },
    },
    {
        default = "alchemy",
        options = {
            {
                description = T("炼金引擎", "Alchemy Engine"),
                data = "alchemy",
            },
            {
                description = T("暗影操纵器", "Shadow Manipulator"),
                data = "magic",
            },
            {
                description = T("远古伪科学站", "Ancient Pseudoscience Station"),
                data = "ancient",
            },
            {
                description = T("月亮祭坛", "Celestial Altar"),
                data = "lunar",
            },
        },
        name = "RECIPE_TECH",
        label = T("解锁科技", "Crafting station"),
        hover = T("决定制作需要的科技站；远古伪科学站和月亮祭坛需在对应科技站附近制作。", "Choose the required station. Ancient and celestial recipes must be crafted near their station."),
    },
    {
        hover = T("决定材料消耗；当前档的完整配方显示在下方选项说明中，与解锁科技独立。", "Choose ingredient costs independently of the station. Full ingredients are shown in the selected option details."),
        name = "RECIPE_DIFFICULTY",
        label = T("制作配方难度", "Crafting recipe"),
        default = "easy",
        options = {
            {
                hover = T("10木板 + 10石砖 + 10绳子 + 10金子", "10 Boards + 10 Cut Stone + 10 Rope + 10 Gold Nuggets"),
                description = T("科学造物", "Scientific Creation"),
                data = "easy",
            },
            {
                hover = T("1捆绑包装袋 + 2黄色月眼 + 2绿色月眼 + 2橙色月眼", "1 Bundling Wrap + 2 Yellow Moonlens + 2 Green Moonlens + 2 Orange Moonlens"),
                description = T("魔法秘藏", "Arcane Cache"),
                data = "normal",
            },
            {
                hover = T("3彩虹宝石 + 9暗影碎布 + 9亮茄外壳 + 3启迪碎片", "3 Iridescent Gems + 9 Dark Tatters + 9 Brightshade Husks + 3 Enlightened Shards"),
                description = T("远古遗物", "Ancient Relic"),
                data = "hard",
            },
        },
    },
    {
        hover = T("在外部14格之外增加50/100/150/200格；每25格为一个单元。已有存档不要降低容量。", "Add 50/100/150/200 internal slots beyond the 14 exterior slots. Each block has 25 slots. Do not reduce capacity in an existing save."),
        name = "SPACE_CAPACITY",
        label = T("次元维度容量", "Dimension capacity"),
        default = 100,
        options = {
            {
                description = T("50格 · 2×1个分区", "50 slots (2×1 blocks)"),
                data = 50,
            },
            {
                description = T("100格 · 2×2个分区", "100 slots (2×2 blocks)"),
                data = 100,
            },
            {
                description = T("150格 · 3×2个分区", "150 slots (3×2 blocks)"),
                data = 150,
            },
            {
                description = T("200格 · 4×2个分区", "200 slots (4×2 blocks)"),
                data = 200,
            },
        },
    },
    {
        hover = T("仅袋内调整可堆叠物品上限；999模式取出时按原版上限分批，余量留在袋内。", "Changes stack limits inside the bag only. With 999 stacks, withdrawals use the original stack size; the rest stays inside."),
        name = "STACK_MODE",
        label = T("虚空袋堆叠上限", "Stack limit"),
        default = 0,
        options = {
            {
                description = T("原版堆叠", "Original limits"),
                data = 0,
            },
            {
                description = T("999堆叠", "999 per stack"),
                data = 999,
            },
        },
    },
    {
        hover = T("袋内腐败物品、蘑菇帽及活鱼均生效；2倍/6倍表示基础腐败速度1/2或1/6，温度等环境因素仍生效；装备在身上不享受袋内加成。", "Applies to perishable items, mushroom hats and live fish inside the bag. 2x/6x means base decay rates of 1/2 or 1/6. Environment still matters; equipped items are unaffected."),
        name = "PRESERVATION",
        label = T("虚空袋保鲜效果", "Preservation"),
        default = "fridge",
        options = {
            {
                description = T("两倍保鲜（冰箱效果）", "2x freshness (Ice Box)"),
                data = "fridge",
            },
            {
                description = T("六倍保鲜（速度1/6）", "6x freshness (1/6 decay)"),
                data = "triple",
            },
            {
                description = T("永久保鲜", "No spoilage"),
                data = "permanent",
            },
        },
    },
    {
        default = "X",
        options = {
            {
                description = "X",
                data = "X",
            },
            {
                description = "Z",
                data = "Z",
            },
            {
                description = "V",
                data = "V",
            },
            {
                description = "B",
                data = "B",
            },
        },
        name = "TOGGLE_KEY",
        label = T("展开/收起次元维度按键", "Open/close key"),
        hover = T("装备并打开虚空袋后，按此键展开或收起次元维度；不会关闭外部14格。", "Open or close the dimension while the bag is equipped and accessible. The exterior 14 slots remain open."),
    },
    {
        hover = T("对内部物品分类排序，耐久/新鲜度降序、宝石按颜色顺序；外部14格保持原位。组合键由下一项配置。", "Sort internal items by category, durability/freshness and gem color. Exterior slots are untouched. Select a modifier below."),
        name = "SORT_KEY",
        label = T("次元校准（智能整理）快捷键", "Sort key"),
        default = "J",
        options = {
            {
                description = "J",
                data = "J",
            },
            {
                description = "K",
                data = "K",
            },
            {
                description = "L",
                data = "L",
            },
        },
    },
    {
        name = "SORT_MODIFIER",
        label = T("次元校准组合键", "Sort modifier"),
        hover = T("无：单按J/K/L；Shift或Ctrl：需按住对应组合键，再按所选快捷键。", "None: press J/K/L alone. Otherwise hold Shift or Ctrl while using the selected sort key."),
        options = {
            {
                description = T("无（单键）", "None (single key)"),
                data = "none",
            },
            {
                description = "Shift",
                data = "shift",
            },
            {
                description = "Ctrl",
                data = "ctrl",
            },
        },
        default = "none",
    },
    {
        hover = T("将身体物品栏和背包外部14格中与次元维度已有物品同名的物品吸入内部；包括蛋/卵等不可堆叠物，不包含不可堆叠工具、武器、护甲和装备。", "Transfer matching types from your inventory and the exterior slots into the dimension. Includes unstackable eggs, but excludes unstackable tools, weapons, armor and equipment."),
        name = "MERGE_KEY",
        label = T("空间吸附快捷键", "Transfer matching items key"),
        default = "N",
        options = {
            {
                description = "N",
                data = "N",
            },
            {
                description = "M",
                data = "M",
            },
            {
                description = "H",
                data = "H",
            },
        },
    },
    {
        hover = T("关闭时自由存放；开启后各25格单元按下方分类限制，优先专属区，满后进入通用区。", "Disabled: free storage. Enabled: each 25-slot block uses its category below; matching blocks are preferred, with overflow to General."),
        name = "EXCLUSIVE_ZONES",
        label = T("次元维度专属分区", "Categorized blocks"),
        default = false,
        options = {
            {
                description = T("关闭（自由布局）", "Off (free layout)"),
                data = false,
            },
            {
                description = T("开启（按类别限制）", "On (categorized)"),
                data = true,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_1",
        label = T("单元 1 分类", "Block 1 category"),
        default = 1,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_2",
        label = T("单元 2 分类", "Block 2 category"),
        default = 2,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_3",
        label = T("单元 3 分类", "Block 3 category"),
        default = 3,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_4",
        label = T("单元 4 分类", "Block 4 category"),
        default = 4,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_5",
        label = T("单元 5 分类", "Block 5 category"),
        default = 0,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_6",
        label = T("单元 6 分类", "Block 6 category"),
        default = 0,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_7",
        label = T("单元 7 分类", "Block 7 category"),
        default = 0,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("按从左到右、从上到下编号；超出当前容量的单元忽略。通用区接受所有物品。", "Blocks are numbered left to right, then top to bottom. Unused blocks are ignored. General accepts all items."),
        name = "ZONE_8",
        label = T("单元 8 分类", "Block 8 category"),
        default = 0,
        options = {
            {
                description = T("通用", "General"),
                data = 0,
            },
            {
                description = T("工具", "Tools"),
                data = 1,
            },
            {
                description = T("武器 / 护甲", "Weapons / Armor"),
                data = 2,
            },
            {
                description = T("穿戴装备", "Clothing"),
                data = 3,
            },
            {
                description = T("可食用", "Food"),
                data = 4,
            },
        },
    },
    {
        hover = T("关闭时校准不合并食物/腐败物，保留各组新鲜度；空间吸附仍按正常堆叠逻辑合并。", "Off: sorting keeps food/perishable stacks separate to preserve freshness groups. Matching-item transfer still stacks normally."),
        name = "STACK_FOOD",
        label = T("次元校准时合并食物", "Merge food when sorting"),
        default = false,
        options = {
            {
                description = T("不合并 (保留独立新鲜度)", "Keep freshness groups"),
                data = false,
            },
            {
                description = T("自动合并堆叠", "Merge stacks"),
                data = true,
            },
        },
    },
    {
        hover = T("调整次元维度底板不透明度；数字越低，越容易看清后方游戏画面。右键拖动上部边框调整位置。", "Lower opacity makes the world easier to see. Right-drag the top border to move the panel."),
        name = "UI_OPACITY",
        label = T("次元维度背景深度", "Background opacity"),
        default = 0.34,
        options = {
            {
                description = T("轻透 (22%不透明)", "Light (22% opacity)"),
                data = 0.22,
            },
            {
                description = T("柔和 (34%不透明)", "Soft (34% opacity)"),
                data = 0.34,
            },
            {
                description = T("清晰 (48%不透明)", "Clear (48% opacity)"),
                data = 0.48,
            },
        },
    },
}
