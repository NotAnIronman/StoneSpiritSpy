local M = {}

function M.new(database, changed)
    local self = {
        showHoverCount = database:GetBool("showHoverCount") ~= false,
        numberOnly = database:GetBool("numberOnly") == true,
        limitToBoxTier = database:GetBool("limitToBoxTier") == true,
    }

    function self:build(parent)
        local title = ui.Text.new(parent)
        title:SetPos(12, 10)
        title:SetSize(-24, 24, 1, 0)
        title.font = id.Font.MUSEO_SANS_15PT_REGULAR
        title.content, title.rgba, title.clickthrough = "Stone Spirit Spy", 0xD8C18FFF, true

        for index, option in ipairs({
            {key="showHoverCount", label="Show count on hover"},
            {key="numberOnly", label="Number only"},
            {key="limitToBoxTier", label="Match carried ore-box tier"},
        }) do
            local button = ui.Button.new(parent)
            button:SetPos(12, 42 + (index - 1) * 40)
            button:SetSize(-24, 32, 1, 0)
            button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
            button.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
            local function refresh()
                button.label = option.label .. ": " .. (self[option.key] and "On" or "Off")
            end
            refresh()
            button:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
                self[option.key] = not self[option.key]
                if not database:SetBool(option.key, self[option.key]) then
                    log("Stone Spirit Spy could not save " .. option.label .. ".")
                end
                refresh()
                changed()
            end)
        end

        local hint = ui.Text.new(parent)
        hint:SetPos(12, 168)
        hint:SetSize(-24, 96, 1, 0)
        hint.font, hint.rgba, hint.clickthrough = id.Font.MUSEO_SANS_15PT_REGULAR, 0xBAC8D4FF, true
        hint.content = "Hover count updates the game's existing hover box.<br>Number only shows Copper rock (17).<br>Tier matching uses your highest-tier carried box."
    end

    return self
end

return M
