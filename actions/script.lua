local mq = require('mq')
local co = require('co')
local common = require('common')
require('actions.action')

function Script(name, queue, timeout, priority, blocking, callback)
    assert(name ~= nil and name:len() > 0)
    queue = queue or {}
    timeout = timeout or 10000
    priority = priority or 99
    callback = callback or function() end

    local context = {}

    local self = Action(name, blocking)
    self.__type__ = 'Script'

    self.Timeout = timeout
    self.Priority = priority
    self.Callback = callback

    -- if type(priority) == 'boolean' then
    --     print('------------- ' .. name)
    -- end

    self.IsSame = function(script)
        return script ~= nil and self.__type__ == script.__type__ and name == script.Name
    end

    self.Add = function(action)
        table.insert(queue, assert(action))
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.Run = function(state, cfg, ctx)
        context = common.CopyAndOverlay(ctx, context)
        for i, action in ipairs(queue) do
            action.Ready = false
            action.Coroutine = coroutine.create(
                function()
                    -- local start = mq.gettime()
                    local skip, reason = action.ShouldSkip(state, cfg, context)
                    if not skip then
                        local ready = co.delay(action.ReadyTimeout, function() return action.IsReady(state, cfg, context) end)
                        if ready then
                            action.Ready = true
                            co.yield()
                            action.Run(state, cfg, context)
                            local finished = co.delay(action.FinishTimeout, function() return action.IsFinished(state, cfg, context) end)
                            if finished then
                                action.PostAction(state, cfg, context)
                            end
                        end
                    -- else
                    --     self.log('Not executing ' .. action.Name .. ' because ' .. reason)
                    end
                    -- self.log('Time for ' .. action.Name .. ': ' .. (mq.gettime() - start))
                end
            )
        end

        local head = 1
        local tail = 1
        while head <= #queue do
            local e = tail
            if e > #queue then e = #queue end
            for i = head, e do
                if coroutine.status(queue[i].Coroutine) ~= 'dead' then
                    local s, err = coroutine.resume(queue[i].Coroutine)
                    if not s then
                        print(self.Name .. ': ' .. err .. ': ' .. i .. ': ' .. head)
                    end
                end
                if i == head and coroutine.status(queue[i].Coroutine) == 'dead' then
                    head = head + 1
                    if tail < head then
                        tail = head
                    end
                end
                if i == tail and not queue[i].Blocking and queue[i].Ready then
                    -- print('Adding next because ' .. queue[i].Name .. ' is non-blocking')
                    tail = tail + 1
                end
                co.yield()
            end
        end
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    self.OnInterrupt = function(state, cfg, ctx)
        for i, action in ipairs(queue) do
            queue[i].OnInterrupt(state, cfg, ctx)
        end
    end

    return self
end
