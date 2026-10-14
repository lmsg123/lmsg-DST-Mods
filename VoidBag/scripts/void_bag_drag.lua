-- 仅客户端的会话位置缓存：以TheWorld实体区分地表/洞穴/重连，不写磁盘或存档。
-- Session-only state keyed by world entity: reconnect/shard changes reset it.
local Drag = {}
local world, position
function Drag.Get()
    if world ~= TheWorld then world, position = TheWorld, nil end
    return position
end
function Drag.Set(x, y)
    world, position = TheWorld, { x = x, y = y }
end
return Drag
