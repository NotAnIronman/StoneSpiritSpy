local M = {}

function M.new(database, changed, diagnostics)
    local self = {
        showHoverCount = database:GetBool("showHoverCount") ~= false,
        numberOnly = database:GetBool("numberOnly") == true,
        limitToBoxTier = database:GetBool("limitToBoxTier") == true,
    }

    function self:build(parent)
        local root = ui.Layer.new(parent)
        root:SetSize(0, 0, 1, 1)
        local host = parent
        parent = root
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

        local record = ui.Button.new(parent)
        record:SetPos(12, 168)
        record:SetSize(-24, 32, 1, 0)
        record.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        record.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
        record.label = "Record hover diagnostics (5 seconds)"
        record:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            diagnostics:start()
            record.label = "Recording: close settings and hover a rock"
        end)

        local report = ui.Button.new(parent)
        report:SetPos(12, 208)
        report:SetSize(-24, 32, 1, 0)
        report.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        report.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
        report.label = "Show diagnostic report"
        report:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
            local snapshot = diagnostics:report()
            root:DeleteAll()
            local back = ui.Button.new(root)
            back:SetPos(12, 10)
            back:SetSize(110, 30)
            back.stylesheetID, back.label = id.StyleSheet.BUTTON_DEFAULT, "Back"
            back.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
            back:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
                root:Destroy()
                self:build(host)
            end)

            local instruction = ui.Text.new(root)
            instruction:SetPos(12, 48)
            instruction:SetSize(-24, 48, 1, 0)
            instruction.font, instruction.rgba = id.Font.MUSEO_SANS_15PT_REGULAR, 0xBAC8D4FF
            instruction.clickthrough = true
            instruction.content = "Click the report field, then press Ctrl+A and Ctrl+C. Paste it into the development chat."

            local field = ui.InputField.new(root)
            field:SetPos(12, 104)
            field:SetSize(-24, -116, 1, 1)
            field.stylesheetID = id.StyleSheet.INPUT_DEFAULT
            field:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 32768)
            field.text.font, field.text.rgba, field.text.maxLines = id.Font.MUSEO_SANS_15PT_REGULAR, 0xDDEEF8FF, 0
            field.scrollbar.visible = true
            field.content = snapshot
        end)

        local hint = ui.Text.new(parent)
        hint:SetPos(12, 250)
        hint:SetSize(-24, 48, 1, 0)
        hint.font, hint.rgba, hint.clickthrough = id.Font.MUSEO_SANS_15PT_REGULAR, 0xBAC8D4FF, true
        hint.content = "Record, then close settings and hover Copper rock.<br>Reopen settings and select Show diagnostic report."
    end

    return self
end

return M
