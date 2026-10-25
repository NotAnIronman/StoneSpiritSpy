local M = {}

M.spirits = {
    {key="copper", name="Copper", id=44799, varID=11514},
    {key="tin", name="Tin", id=44800, varID=11515},
    {key="iron", name="Iron", id=44801, varID=11516},
    {key="silver", name="Silver", id=44802, varID=11518},
    {key="gold", name="Gold", id=44803, varID=11519},
    {key="coal", name="Coal", id=44804, varID=11517},
    {key="mithril", name="Mithril", id=44805, varID=11520},
    {key="luminite", name="Luminite", id=44806, varID=11523},
    {key="adamantite", name="Adamantite", id=44807, varID=11521},
    {key="runite", name="Runite", id=44808, varID=11522},
    {key="orichalcite", name="Orichalcite", id=44809, varID=11524},
    {key="drakolith", name="Drakolith", id=44810, varID=11525},
    {key="necrite", name="Necrite", id=44811, varID=11526},
    {key="phasmatite", name="Phasmatite", id=44812, varID=11527},
    {key="banite", name="Banite", id=44813, varID=11528},
    {key="light_animica", name="Light animica", id=44814, varID=11529},
    {key="dark_animica", name="Dark animica", id=44815, varID=11530},
}

M.boxes = {}
for index = 1, 10 do
    M.boxes[44777 + index * 2] = true
end

local byItem, rocks = {}, {}
for _, spirit in ipairs(M.spirits) do
    byItem[spirit.id] = spirit
    spirit.varName = "MINING_OREBOX_" .. spirit.key:upper() .. "_STONE_SPIRIT_VAR"
    local name = spirit.name:lower()
    for _, suffix in ipairs({"", " rock", " rocks", " ore rock", " ore rocks"}) do
        rocks[name .. suffix] = spirit
    end
end
rocks["concentrated coal rocks"] = byItem[44804]
rocks["concentrated gold rocks"] = byItem[44803]
rocks["adamant rock"] = byItem[44807]
rocks["adamant rocks"] = byItem[44807]
rocks["rune rock"] = byItem[44808]
rocks["rune rocks"] = byItem[44808]
rocks["bane rock"] = byItem[44813]
rocks["bane rocks"] = byItem[44813]

function M.normalise(value)
    if type(value) ~= "string" then return "" end
    return value:gsub("<[^>]*>", ""):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function M.rock(name) return rocks[M.normalise(name)] end
function M.item(id) return byItem[id] end
function M.isCount(value)
    return type(value) == "number" and value >= 0 and value <= 2147483647 and value % 1 == 0
end

function M.label(spirit, count)
    if count == nil then return spirit.name .. " Stone Spirits: unavailable" end
    local number = string.format("%.0f", count)
    number = number:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return number .. " " .. spirit.name .. (count == 1 and " Stone Spirit" or " Stone Spirits")
end

return M
