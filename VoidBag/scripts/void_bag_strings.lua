-- require模块使用游戏全局环境，不能假定存在modmain专属的GLOBAL。
-- 与modinfo同样读取官方locale；中文保留中文，其余语言统一回退英文。
local LOC = require("languages/loc")
local lang = LOC.GetLocaleCode()
local chinese = lang == "zh" or lang == "zht" or lang == "zhr"
local zh = {
    BAG_NAME="虚空袋", SPACE_NAME="次元维度", RECIPE_DESC="折叠空间，容纳万物。",
    SORT_NAME="次元校准", MERGE_NAME="空间吸附", CLOSE_NAME="收起", DRAG_HINT="鼠标右键移动",
    CAPACITY_FORMAT="%d 格  ·  每区 25 格", INSPECT_FORMAT="按 %s 键展开次元维度，按 %s 键空间吸附。",
    ZONE_TITLES={[0]="通用", "工具", "武器 / 护甲", "穿戴装备", "可食用"},
    ZONE_FULL="对应专区容量不足，请先腾出位置；物品未移动。",
    ZONE_FALLBACK="内容超出当前专区容量，暂用自由布局；腾出位置后再次次元校准。",
    MERGE_SUCCESS="已将 %d 组同类物品吸附至次元维度！",
    MERGE_EMPTY="没有可补入的同类物品，或次元维度已满。",
}
local en = {
    BAG_NAME="Void Bag", SPACE_NAME="Dimension", RECIPE_DESC="Folded space, room for everything.",
    SORT_NAME="Sort Space", MERGE_NAME="Match & Store", CLOSE_NAME="Close", DRAG_HINT="Right-drag to move",
    CAPACITY_FORMAT="%d slots  ·  25 per block", INSPECT_FORMAT="Press %s to open the dimension, or %s to transfer matching items.",
    ZONE_TITLES={[0]="General", "Tools", "Weapons / Armor", "Clothing", "Food"},
    ZONE_FULL="Not enough space in the matching blocks. Make room first; items were not moved.",
    ZONE_FALLBACK="Items exceed the current block limits. Using a free layout until you make room and sort again.",
    MERGE_SUCCESS="Transferred %d matching stacks into the dimension!",
    MERGE_EMPTY="No matching items to transfer, or the dimension is full.",
}
local display = chinese and zh or en
display.BUTTON_FONT_SIZE = chinese and 30 or 24
display.ZONE_FONT_SIZE = chinese and 34 or 28 -- 英文标签较长，只缩小英文。
-- 服务端仅向目标玩家发送稳定消息键，由接收客户端按自己的语言生成文本。
-- 混合语言服务器不能在服务端拼好中文后通过talker广播。
function display.Notify(player, key, count)
    if player and player.userid then
        SendModRPCToClient(GetClientModRPC("VoidBagRPC", "Notice"), player.userid, key, count or 0)
    end
end
return display
