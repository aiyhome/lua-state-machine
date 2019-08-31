function var_dump(data, max_level, prefix)   
    if type(prefix) ~= "string" then   
        prefix = ""  
    end   
    if type(data) ~= "table" then   
        print(prefix .. tostring(data))   
    else  
        print(data)   
        if max_level ~= 0 then   
            local prefix_next = prefix .. "    "  
            print(prefix .. "{")   
            for k,v in pairs(data) do  
                io.stdout:write(prefix_next .. k .. " = ")   
                if type(v) ~= "table" or (type(max_level) == "number" and max_level <= 1) then   
                    print(v)   
                else  
                    if max_level == nil then   
                        var_dump(v, nil, prefix_next)   
                    else  
                        var_dump(v, max_level - 1, prefix_next)   
                    end   
                end   
            end   
            print(prefix .. "}")   
        end   
    end   
end

local StateMachine = require("StateMachine")
local fsm = StateMachine.new({
  init='solid',
  transitions={
    { name='melt',     from='*',  to='liquid' },
    { name='freeze',   from='liquid', to='solid'  },
    { name='vaporize', from='liquid', to='gas'    },
    { name='condense', from='gas',    to='liquid' }
  },
  methods={
    onMelt=    function(...) print(...);print('I melted')    end,
    onFreeze=  function()  print('I froze')     end,
    onVaporize=function()  print('I vaporized') end,
    onBeforeMelt=function()  print('onBeforeMelt') end,
    onEnterLiquid=function()  print('onEnterLiquid') end,
    onLeaveLiquid=function()  print('onLeaveLiquid') end,
    onCondense=function()  print('I condensed') end
  }
})

local observer = {}

function observer:onMelt(transition, extdata)
  -- var_dump(transition)
  -- var_dump(extdata)
  print('observer.onMelt', self.v)
end

function observer.new(v)
  local instance = {}
  setmetatable(instance,{__index = observer})
  instance.v = v
  return instance
end

fsm:observe(observer.new(1))

fsm:observe(observer.new(2))
-- fsm:observe("onMelt", function ()
--   print("test")
-- end)
-- var_dump(fsm, 5)

fsm:melt()
-- fsm:melt()
-- fsm:freeze()
fsm:vaporize()
fsm:condense()
-- print(fsm:is({"liquid"}))
-- print(fsm:can("freeze"))
-- var_dump(fsm:transitions())