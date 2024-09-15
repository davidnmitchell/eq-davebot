local mq = require('mq')
local co = require('co')
require('eqclass')

local MyClass = EQClass:new()

local function train_lang(lang, count)
    mq.cmd('/lang ' .. lang)
    co.delay(50)
    mq.cmd('/g Hello, this is #' .. count)
    co.delay(50)
    mq.cmd('/g This is a language')
    co.delay(50)
    mq.cmd('/g I am trying to learn it')
    co.delay(50)
end

local function train_langs(langs, count)
    for i, lang in ipairs(langs) do
        train_lang(lang, count)
    end
end

local function train_all_langs(times)
    local langs = {}
    for i=1,23 do
        table.insert(langs, i)
    end
    for i=1,times do
        train_langs(langs, i)
    end
    mq.cmd('/lang 1')
end

return {
    Run = function(...)
        local args = { ... }
        if args[1] == 'lang' then
            train_all_langs(tonumber(args[2]))
        end
    end
}
