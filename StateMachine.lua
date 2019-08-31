--[[

copy from Javascript State Machine Library

https://github.com/jakesgordon/javascript-state-machine

JS Version: 3.0.1

]]
local Camelize = require("Camelize")
local Config = require("SMachineConfig")

local UNOBSERVED = { nil, {} }

local StateMachine = {}

StateMachine.version  = '3.0.1'
StateMachine.defaults = {
  wildcard = '*',
  init = {
    name = 'init',
    from = 'none'
  }
}

function StateMachine.new(options, args)
  local base = {}
  base.__index = base
  setmetatable(base,{__index = StateMachine})

  local config = Config.new(options, StateMachine)
  base.config    = config
  base.state     = config.init.from

  local instance = config.methods or {}
  base.observers = {instance}

  local transitions = config:allTransitions()
  for _,v in pairs(transitions) do
    local name = v
    instance[Camelize.camelize(name)] = function(inst_,...) 
      return inst_.fire(inst_, name, {...})
    end
  end
  setmetatable(instance, base)

  instance:init(args)
  return instance
end

function StateMachine:init(args)
  local appendProperties = self.config.data(self, table.unpack(args))
  if appendProperties then
    for k,v in pairs(appendProperties) do
      self[k] = v
    end
  end
  if self.config.init.active then
    return self:fire(self.config.init.name)
  end
end

function StateMachine:is(state)
  if type(state) == 'table' then
    for _,v in ipairs(state) do
      if v == self.state then
        return true
      end
    end
  else 
    return self.state == state
  end
end

function StateMachine:isPending()
  return self.pending
end

function StateMachine:can(transition) 
  return not self:isPending() and (not not self:seek(transition))
end

function StateMachine:cannot(transition)
  return not self:can(transition)
end

function StateMachine:allStates()
  return self.config:allStates()
end

function StateMachine:allTransitions()
  return self.config:allTransitions()
end

function StateMachine:transitions()
  return self.config:transitionsFor(self.state)
end

function StateMachine:seek(transition, args) 
  local wildcard = self.config.defaults.wildcard
  local entry    = self.config:transitionFor(self.state, transition)
  local to       = entry and entry.to
  if type(to) == 'function' then
    return to(self, unpack(args))
  elseif to == wildcard then
    return self.state
  else
    return to
  end
end

function StateMachine:fire(transition, args)
  args = args or {}
  if type(args) ~= 'table' then
    args = {args}
  end
  --notice: args must pure array
  return self:transit(transition, self.state, self:seek(transition, args), args)
end

function StateMachine:transit(transition, from, to, args) 
  local lifecycle = self.config.lifecycle;
  local changed   = self.config.options.observeUnchangedState or (from ~= to)

  if not to then
    return self:onInvalidTransition(transition, from, to)
  end

  if self:isPending() then
    return self:onPendingTransition(transition, from, to)
  end

  self.config:addState(to) -- might need to add this state if it's unknown (e.g. conditional transition or goto)

  self:beginTransit()

  table.insert(args,1,{  -- this context will be passed to each lifecycle event observer
      transition= transition,
      from=       from,
      to=         to,
      -- fsm=        self
    })
  
  local events = {
    self:observersForEvent(lifecycle.onBefore.transition),
    self:observersForEvent(lifecycle.onBefore[transition]),
    changed and self:observersForEvent(lifecycle.onLeave.state) or UNOBSERVED,
    changed and self:observersForEvent(lifecycle.onLeave[from]) or UNOBSERVED,
              self:observersForEvent(lifecycle.on.transition),
    changed and { 'doTransit', {self} }                         or UNOBSERVED,
    changed and self:observersForEvent(lifecycle.onEnter.state) or UNOBSERVED,
    changed and self:observersForEvent(lifecycle.onEnter[to])   or UNOBSERVED,
    changed and self:observersForEvent(lifecycle.on[to])        or UNOBSERVED,
    self:observersForEvent(lifecycle.onAfter.transition),
    self:observersForEvent(lifecycle.onAfter[transition]),
    self:observersForEvent(lifecycle.on[transition])
  }
  return self:observeEvents(events, args)
end

function StateMachine:beginTransit()
  self.pending = true
end
  
function StateMachine:endTransit(result)
  self.pending = false
  return result
end

function StateMachine:failTransit(result)
  self.pending = false
  assert(false,result)
end

function StateMachine:doTransit(lifecycle)
  self.state = lifecycle.to
end

function StateMachine:observe(...) 
  if select('#',...) == 2 then
    local observer = {}
    local name = select(1,...)
    observer[name] = select(2,...)
    table.insert(self.observers,observer)
  else
    table.insert(self.observers,select(1,...))
  end
end

function StateMachine:observersForEvent(event) --TODO: this could be cached
  local max = #self.observers
  local result = {}
  local observer
  for n=1,max do
    observer = self.observers[n]
    if observer[event] then
      table.insert(result, observer)
    end
  end
  return {event, result, true}
end

function StateMachine:observeEvents(events, args, previousEvent, previousResult) 
  if #events == 0 then
    return self:endTransit(previousResult == nil and true or previousResult)
  end

  local event = events[1][1]
  local observers = events[1][2]
  local pluggable = events[1][3]
  args[1].event = event
  if #observers == 0 then
    table.remove(events, 1)
    return self:observeEvents(events, args, event, previousResult)
  else
    local observer = table.remove(observers, 1)
    local result = observer[event](observer, table.unpack(args))
    if result == false then
      return self:endTransit(false)
    else 
      return self:observeEvents(events, args, event, result)
    end
  end
end

function StateMachine:onInvalidTransition(transition, from, to)
  print("transition is invalid in current state", transition, from, to, self.state)
end

function StateMachine:onPendingTransition(transition, from, to)
  print("transition is invalid while previous transition is still in progress", transition, from, to, self.state)
end

return StateMachine