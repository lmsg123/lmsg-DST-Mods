-- 仅客户端：透明底板、官方细线素材、分类标记与右键拖动；隐藏槽由原生ContainerWidget创建并重挂到本面板。
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local ImageButton = require("widgets/imagebutton")
local display = require("void_bag_strings")
local Drag = require("void_bag_drag")

local Panel = Class(Widget, function(self, layout, offset, opacity, sortfn, mergefn, closefn)
    Widget._ctor(self, "DimensionPanel")
    self.layout, self.offset = layout, offset
    self:SetPosition(offset, 100, 0)
    self:SetScale(.6)
    self.header = self:AddChild(Image("images/global.xml", "square.tex"))
    self.header:SetSize(layout.panelwidth - 145, layout.zone_names and 70 or 60)
    self.header:SetPosition(-60, layout.height / 2 + (layout.zone_names and 96 or 39), 0)
    self.header:SetTint(.25, .17, .35, .12)
    self.header:SetHoverText(display.DRAG_HINT, {font=BODYTEXTFONT, font_size=16, bg=false, offset_y=18})
    self.header.OnMouseButton = function(_, button, down)
        if button ~= MOUSEBUTTON_RIGHT then return false end
        if down then
            local mouse = TheInput:GetScreenPosition()
            local pos = self:GetPosition()
            self.dragstart = { mousex = mouse.x, mousey = mouse.y, x = pos.x, y = pos.y }
        else self.dragstart = nil end
        return true
    end
    local function rectangle(w, h, x, y, r, g, b, a)
        local image = self:AddChild(Image("images/global.xml", "square.tex"))
        image:SetSize(w, h)
        image:SetPosition(x, y, 0)
        image:SetTint(r, g, b, a)
        image:SetClickable(false)
        return image
    end
    -- A light veil plus separate block outlines keeps the world visible.
    rectangle(layout.panelwidth, layout.panelheight, 0, layout.panelcenter, .025, .020, .045, opacity)
    -- A two-pixel outline fits the content instead of adding fixed-size art
    -- outside it. Short inset corners provide a restrained geometric accent.
    local fw, fh = layout.panelwidth, layout.panelheight
    local function frame_line(texture, w, h, x, y)
        local line = self:AddChild(Image("images/ui.xml", texture))
        line:SetSize(w, h)
        line:SetPosition(x, y, 0)
        line:SetTint(.82, .68, .43, .8)
        line:SetClickable(false)
    end
    frame_line("line_horizontal_1.tex", fw, 5, 0, layout.panelcenter + fh/2)
    frame_line("line_horizontal_1.tex", fw, 5, 0, layout.panelcenter - fh/2)
    frame_line("line_vertical_1.tex", 5, fh, -fw/2, layout.panelcenter)
    frame_line("line_vertical_1.tex", 5, fh, fw/2, layout.panelcenter)
    local gold = { .73, .60, .34, .65 }
    rectangle(layout.panelwidth, 2, 0, layout.height / 2 + (layout.zone_names and 135 or 70), unpack(gold))
    local flourish = self:AddChild(Image("images/global_redux.xml", "item_divider.tex"))
    flourish:SetSize(math.min(460, layout.panelwidth * .5), 12)
    flourish:SetPosition(0, layout.height / 2 + (layout.zone_names and 48 or 2), 0)
    flourish:SetTint(.9, .78, .5, .8)
    flourish:SetClickable(false)
    for _, block in ipairs(layout.blocks) do
        local edge = 5 * layout.step + 8
        rectangle(edge, edge, block.x, block.y, .16, .11, .23, .10)
        rectangle(edge, 1.5, block.x, block.y + edge / 2, .73, .60, .34, .38)
        rectangle(edge, 1.5, block.x, block.y - edge / 2, .73, .60, .34, .38)
        rectangle(1.5, edge, block.x - edge / 2, block.y, .73, .60, .34, .38)
        rectangle(1.5, edge, block.x + edge / 2, block.y, .73, .60, .34, .38)
    end
    local title = self:AddChild(Text(HEADERFONT, 58, display.SPACE_NAME))
    if layout.zone_names then
        for i, block in ipairs(layout.blocks) do
            local icon = self:AddChild(Image("images/crafting_menu_icons.xml", require("void_bag_zones").Icon(i)))
            icon:SetSize(48, 48)
            icon:SetPosition(block.x - 115, block.y + 2.5 * layout.step + 25, 0)
            icon:SetClickable(false)
            local label = self:AddChild(Text(BODYTEXTFONT, display.ZONE_FONT_SIZE, layout.zone_names[i]))
            label:SetPosition(block.x + 20, block.y + 2.5 * layout.step + 25, 0)
            label:SetColour(.9, .8, .58, 1)
            label:SetClickable(false)
        end
    end
    title:SetPosition(0, layout.height / 2 + (layout.zone_names and 110 or 52), 0)
    title:SetColour(.90, .80, .58, 1)
    title:SetClickable(false)
    local subtitle = self:AddChild(Text(BODYTEXTFONT, 20, string.format(display.CAPACITY_FORMAT, layout.capacity)))
    subtitle:SetPosition(0, layout.height / 2 + (layout.zone_names and 70 or 15), 0)
    subtitle:SetColour(.78, .75, .82, 1)
    subtitle:SetClickable(false)
    local function button(label, x, fn)
        local b = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex"))
        b:SetPosition(x, -layout.height / 2 - 43, 0)
        b:SetText(label)
        b:SetFont(BUTTONFONT)
        b:SetTextSize(display.BUTTON_FONT_SIZE)
        b:SetOnClick(fn)
        return b
    end
    self.sortbutton = button(display.SORT_NAME, -120, sortfn)
    self.mergebutton = button(display.MERGE_NAME, 120, mergefn)
    -- 使用原版关闭叉号：无长条底板，固定点击区域，不依赖字体是否有×字形。
    self.closebutton = self:AddChild(ImageButton("images/global_redux.xml", "close.tex"))
    self.closebutton:SetPosition(layout.panelwidth / 2 - 40, layout.height / 2 + (layout.zone_names and 96 or 40), 0)
    self.closebutton:ForceImageSize(52, 52)
    self.closebutton:SetImageNormalColour(.90, .80, .58, 1)
    self.closebutton:SetImageFocusColour(1, .93, .74, 1)
    self.closebutton:SetHoverText(display.CLOSE_NAME, {font=BODYTEXTFONT, font_size=18, bg=false})
    self.closebutton:SetOnClick(closefn)
    self:StartUpdating()
end)

function Panel:RefreshLayout()
    local w, h = TheSim:GetScreenSize()
    local parentScale = self.parent and self.parent:GetScale() or Vector3(1, 1, 1)
    if self.lastw == w and self.lasth == h and self.lastscale == parentScale.x then return end
    self.lastw, self.lasth, self.lastscale = w, h, parentScale.x
    local scale = math.min(.68,
        w * .72 / (self.layout.panelwidth * parentScale.x),
        h * .70 / (self.layout.panelheight * parentScale.y))
    self:SetScale(scale)
    self.layoutscale = scale
    -- Position in the center-anchored HUD root, above screen center.
    local remembered = Drag.Get()
    self:SetPosition(remembered and remembered.x or self.offset,
        remembered and remembered.y or h * .05 / parentScale.y, 0)
end

function Panel:OnUpdate()
    self:RefreshLayout()
    if self.dragstart then
        if not self.shown or not TheInput:IsMouseDown(MOUSEBUTTON_RIGHT) then self.dragstart = nil; return end
        local mouse = TheInput:GetScreenPosition()
        local parentScale = self.parent and self.parent:GetScale() or Vector3(1, 1, 1)
        local x = self.dragstart.x + (mouse.x - self.dragstart.mousex) / parentScale.x
        local y = self.dragstart.y + (mouse.y - self.dragstart.mousey) / parentScale.y
        -- Keep the whole panel on screen, so its title remains reachable.
        local w, h = TheSim:GetScreenSize()
        local maxx = math.max(0, w / (2 * parentScale.x) - self.layout.panelwidth * self.layoutscale / 2 - 12)
        local maxy = math.max(0, h / (2 * parentScale.y) - self.layout.panelheight * self.layoutscale / 2 - 12)
        x = math.max(-maxx, math.min(maxx, x))
        y = math.max(-maxy, math.min(maxy, y))
        self:SetPosition(x, y, 0)
        Drag.Set(x, y)
    end
end

return Panel
