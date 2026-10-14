-- 共享几何：格子72单位，25格单元连续编号。框体上下范围分别贴合标题与按钮；槽号变化会影响存档。
-- Shared geometry: one block = 25 consecutive slots, read left-to-right/top-to-bottom.
local Layout = {}

function Layout.Create(capacity, zones)
    local blockcols = capacity == 50 and 2 or capacity / 50
    local blockrows = capacity == 50 and 1 or 2
    local step, gap = 72, zones and 76 or 28
    local width = blockcols * 5 * step + (blockcols - 1) * gap
    local height = blockrows * 5 * step + (blockrows - 1) * gap
    local result = {
        capacity = capacity, blockcols = blockcols, blockrows = blockrows,
        step = step, gap = gap, width = width, height = height,
        panelwidth = width + 48, panelheight = height + (zones and 220 or 160), panelcenter = zones and 40 or 10,
        zone_names = zones and require("void_bag_zones").Names() or nil,
        slots = {}, blocks = {},
    }
    for by = 0, blockrows - 1 do
        for bx = 0, blockcols - 1 do
            local cx = -width / 2 + 2.5 * step + bx * (5 * step + gap)
            local cy = height / 2 - 2.5 * step - by * (5 * step + gap)
            result.blocks[#result.blocks + 1] = { x = cx, y = cy }
            for row = 0, 4 do
                for col = 0, 4 do
                    result.slots[#result.slots + 1] = {
                        x = cx + (col - 2) * step,
                        y = cy + (2 - row) * step,
                    }
                end
            end
        end
    end
    return result
end

return Layout
