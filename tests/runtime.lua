local Catalog = require("lib/catalog")
local Reader = require("lib/reader")
local total = 0
local function equal(actual, expected)
    assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    fn()
    total = total + 1
    print("PASS " .. name)
end
local function field(spirit, value)
    return {id=spirit.varID, configName=spirit.varName, value=value}
end
local bag, variables, online, reads, reader
local function reset()
    bag, variables, online, reads = {}, {}, true, 0
    reader = Reader.new({
        backpackID=93,
        available=function() return online end,
        slots=function(id) reads=reads+1; return bag end,
        variableByName=function(name) return variables[name] end,
        variableByID=function(id)
            for _, cfg in pairs(variables) do if cfg.id == id then return cfg end end
        end,
    })
end
local copper = Catalog.rock("Copper rock")

test("all 17 storage bindings agree with the supplied native VarPlayer dump", function()
    equal(#Catalog.spirits, 17)
    for _, spirit in ipairs(Catalog.spirits) do
        equal(dumpVariables[spirit.varName], spirit.varID)
    end
end)

test("every supported rock resolves its own spirit", function()
    for _, spirit in ipairs(Catalog.spirits) do
        equal(Catalog.rock(spirit.name .. " rock"), spirit)
        equal(Catalog.item(spirit.id), spirit)
        equal(Catalog.rock("<col=ffff00>" .. spirit.name .. " rocks</col>"), spirit)
    end
    equal(Catalog.rock("Concentrated gold rocks").key, "gold")
    equal(Catalog.rock("Concentrated coal rocks").key, "coal")
    equal(Catalog.rock("Sandstone rock"), nil)
    equal(Catalog.rock("Gem rock"), nil)
    equal(Catalog.rock("Copper ore box"), nil)
end)

test("all ten unnoted ore boxes are detected and noted IDs are excluded", function()
    for id=44779,44797,2 do
        reset()
        bag = {{obj={id=id}, count=1}}
        equal(reader:hasBox(), true)
        bag = {{obj={id=id+1}, count=1}}
        reader:inventoryChanged({id=93})
        equal(reader:hasBox(), false)
    end
end)

test("empty backpack and zero-count box slots are not carried boxes", function()
    reset()
    equal(reader:hasBox(), false)
    bag = {{obj={id=44779}, count=0}}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), false)
end)

test("current spirit values update without opening or hovering an ore box", function()
    reset()
    local value = field(copper, 248)
    variables[copper.varName] = value
    equal(reader:count(copper), 248)
    value.value = 247
    equal(reader:count(copper), 247)
    value.value = 0
    equal(reader:count(copper), 0)
    value.value = 2147483647
    equal(reader:count(copper), 2147483647)
end)

test("missing, unreadable and invalid values remain unavailable", function()
    reset()
    equal(reader:count(copper), nil)
    for _, value in ipairs({-1, 1.5, math.huge, "248", 2147483648}) do
        variables[copper.varName] = field(copper, value)
        equal(reader:count(copper), nil)
    end
    variables[copper.varName] = setmetatable({}, {__index=function() error("unavailable") end})
    equal(reader:count(copper), nil)
end)

test("numeric fallback verifies the exact native field name", function()
    local cfg = field(copper, 248)
    local fallback = Reader.new({
        variableByName=function() error("name unavailable") end,
        variableByID=function(id) equal(id, 11514); return cfg end,
    })
    equal(fallback:count(copper), 248)
    cfg.configName = "SOME_OTHER_VARIABLE"
    equal(fallback:count(copper), nil)
end)

test("backpack spirits and ore counts cannot inflate stored spirits", function()
    reset()
    bag = {{obj={id=44797}, count=1}, {obj={id=copper.id}, count=1000}, {obj={id=436}, count=150}}
    variables[copper.varName] = field(copper, 248)
    equal(reader:hasBox(), true)
    equal(reader:count(copper), 248)
end)

test("multiple ore boxes share one count", function()
    reset()
    bag = {{obj={id=44779}, count=1}, {obj={id=44797}, count=1}}
    variables[copper.varName] = field(copper, 248)
    equal(reader:hasBox(), true)
    equal(reader:count(copper), 248)
end)

test("box deposit, withdrawal, logout and re-login invalidate carried state", function()
    reset()
    bag = {{obj={id=44779}, count=1}}
    equal(reader:hasBox(), true)
    equal(reader:hasBox(), true)
    equal(reads, 1)
    bag = {}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), false)
    bag = {{obj={id=44797}, count=1}}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), true)
    online = false
    equal(reader:hasBox(), false)
    bag, online = {}, true
    equal(reader:hasBox(), false)
end)

test("labels preserve full counts and distinguish zero from unavailable", function()
    equal(Catalog.label(copper, 248), "248 Copper Stone Spirits")
    equal(Catalog.label(copper, 0), "0 Copper Stone Spirits")
    equal(Catalog.label(copper, 1), "1 Copper Stone Spirit")
    equal(Catalog.label(copper, 2147483647), "2,147,483,647 Copper Stone Spirits")
    equal(Catalog.label(copper, nil), "Copper Stone Spirits: unavailable")
end)

local handlers, logs, available, nativeBag, nativeValues
local function boot()
    handlers, logs, available, nativeBag, nativeValues = {}, {}, true, {}, {}
    Event = setmetatable({}, {__index=function(self, name)
        local event = {
            Subscribe=function(reference, callback) handlers[name]=callback end,
            Unsubscribe=function(reference) handlers[name]=nil end,
        }
        rawset(self, name, event)
        return event
    end})
    config = {Inv={INV={id=93}}}
    var = {VarPlayer=setmetatable({FromID=function(id)
        for _, cfg in pairs(nativeValues) do if cfg.id == id then return cfg end end
    end}, {__index=function(_, name) return nativeValues[name] end})}
    Player = {IsAvailable=function() return available end}
    Inventory = {Find=function(id)
        equal(id, 93)
        return {isValid=true, GetSlots=function() return nativeBag end}
    end}
    MiniMenuEntryType = {LOC=3, NPC=4, OBJ=2, INTERFACE=1}
    log = function(message) logs[#logs+1]=message end
    dofile(pluginRoot .. "/main.lua")
end
local function rock(name)
    return {actionEntryType=3, subjectText=name, locData={config={name=name}},
        fullText="Mine <col=ffff00>" .. name .. "</col>", actionType=3}
end
local function hover(entries) handlers.MiniMenuReady({miniMenu={entries=entries}}) end

test("real entrypoint shows the requested 248 Copper Stone Spirits next to the rock", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    local value = field(copper, 248)
    nativeValues[copper.varName] = value
    local entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, "Mine <col=ffff00>Copper rock</col> <col=80d8ff>(248 Copper Stone Spirits)</col>")
    equal(entry.actionType, 3)
    value.value = 247
    hover({entry})
    equal(entry.overrideText, "Mine <col=ffff00>Copper rock</col> <col=80d8ff>(247 Copper Stone Spirits)</col>")
end)

test("real entrypoint reads all 17 spirits using the actual dump bindings", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    for index, spirit in ipairs(Catalog.spirits) do
        nativeValues[spirit.varName] = field(spirit, index)
        local entry = rock(spirit.name .. " rock")
        hover({entry})
        assert(entry.overrideText:find(Catalog.label(spirit, index), 1, true))
    end
end)

test("real entrypoint annotates mine and examine without changing either action", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 248)
    local mine, examine = rock("Copper rock"), rock("Copper rock")
    examine.fullText, examine.actionType = "Examine Copper rock", 1002
    hover({mine, examine})
    assert(mine.overrideText:find("248 Copper Stone Spirits", 1, true))
    assert(examine.overrideText:find("248 Copper Stone Spirits", 1, true))
    equal(mine.actionType, 3)
    equal(examine.actionType, 1002)
end)

test("real entrypoint leaves unrelated menus and missing boxes unchanged", function()
    boot()
    local entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, nil)
    nativeBag = {{obj={id=44779}, count=1}}
    handlers.InventoryUpdated({inv={id=93}})
    local npc, item, sand = rock("Copper rock"), rock("Copper rock"), rock("Sandstone rock")
    npc.actionEntryType, item.actionEntryType = 4, 2
    hover({npc, item, sand})
    equal(npc.overrideText, nil)
    equal(item.overrideText, nil)
    equal(sand.overrideText, nil)
end)

test("real entrypoint preserves other plugin text and reports unknown storage", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    local entry = rock("Copper rock")
    entry.overrideText = "Mine Copper rock [other plugin]"
    hover({entry})
    equal(entry.overrideText, "Mine Copper rock [other plugin] <col=80d8ff>(Copper Stone Spirits: unavailable)</col>")
end)

test("real entrypoint updates after deposit and resumes on withdrawal", function()
    boot()
    nativeValues[copper.varName] = field(copper, 248)
    nativeBag = {{obj={id=44779}, count=1}}
    local entry = rock("Copper rock")
    hover({entry})
    assert(entry.overrideText)
    nativeBag = {}
    handlers.InventoryUpdated({inv={id=93}})
    hover({entry})
    equal(entry.overrideText, "")
    entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, nil)
    nativeBag = {{obj={id=44797}, count=1}}
    handlers.InventoryAdded({inv={id=93}})
    entry = rock("Copper rock")
    hover({entry})
    assert(entry.overrideText:find("248 Copper Stone Spirits", 1, true))
end)

test("real entrypoint performs no Draw or Logic work and unsubscribes on shutdown", function()
    boot()
    equal(handlers.Draw, nil)
    equal(handlers.Logic, nil)
    handlers.PluginShutdown({})
    equal(next(handlers), nil)
end)

print(string.format("%d checks passed. Native hover rendering still requires in-game validation.", total))
