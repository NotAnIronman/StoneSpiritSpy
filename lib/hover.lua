local M = {}

function M.new()
    local self = {}
    local root, parent, label, background, lastText, width

    function self:hide()
        if root then pcall(function() root.hidden = true end) end
    end

    function self:clear()
        if root then pcall(function() root:Destroy() end) end
        root, parent, label, background, lastText, width = nil, nil, nil, nil, nil, nil
    end

    function self:show(content)
        if not Mouse.IsAvailable() then self:hide(); return end
        local mouse = Mouse.GetPosition()
        if not mouse then self:hide(); return end
        if not root then
            parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
            if not parent then return end
            root = ui.Layer.new(parent)
            root.clickthrough = true
            background = ui.Rectangle.new(root)
            background.fill, background.rgba, background.clickthrough = true, 0x111B24F0, true
            label = ui.Text.new(root)
            label:SetPos(8, 3)
            label.font, label.rgba, label.clickthrough = id.Font.MUSEO_SANS_15PT_REGULAR, 0xDDEEF8FF, true
            label.maxLines = 1
        end

        if content ~= lastText then
            width = config.Font.FromID(id.Font.MUSEO_SANS_15PT_REGULAR):GetStringWidth(content, false) + 16
            label.content, lastText = content, content
        end
        local boxWidth = math.min(width, math.max(1, parent.width - 12))
        root:SetSize(boxWidth, 28)
        background:SetSize(boxWidth, 28)
        label:SetSize(math.max(1, boxWidth - 16), 22)

        local percent = game.options.InterfaceScale.setting
        local scale = type(percent) == "number" and percent > 0 and percent / 100 or 1
        local origin = parent.xyGlobal
        local mouseX, mouseY = mouse.x / scale - origin.x, mouse.y / scale - origin.y
        local x, y = mouseX + 16, mouseY + 28
        if x + boxWidth > parent.width then x = mouseX - boxWidth - 12 end
        if y + 28 > parent.height then y = mouseY - 34 end
        root:SetPos(math.floor(math.max(0, math.min(parent.width - boxWidth, x))),
            math.floor(math.max(0, math.min(parent.height - 28, y))))
        root.hidden = false
    end

    return self
end

return M
