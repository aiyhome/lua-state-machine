local Camelize = require("Camelize")

local Config = {}

local function isInTable(tbl, v)
  for k,v in pairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

local function mixin(target, ...)
  local n = select('#', ...)
  local source
  for i=1,n do
    source = select(i,...)
    for k,v in pairs(source) do
       target[k] = v
    end
  end
  return target
end

function Config.new(options, StateMachine)
  local instance = {}
  setmetatable(instance, {__index = Config})
  instance.options = options or {}
  instance.defaults = StateMachine.defaults
  instance.map = {}
  instance.states = {}
  instance.transitions = {}
  instance.lifecycle = instance:configureLifecycle()
  instance.init      = instance:configureInitTransition(options.init)

  instance.data        = instance:configureData(options.data)
  instance.methods     = instance:configureMethods(options.methods)
  instance.map[instance.defaults.wildcard] = {}

  instance:configureTransitions(options.transitions or {})
  return instance
end

function Config:configureLifecycle() 
  return {
    onBefore  = { transition = 'onBeforeTransition' },
    onAfter   = { transition = 'onAfterTransition'  },
    onEnter   = { state      = 'onEnterState'       },
    onLeave   = { state      = 'onLeaveState'       },
    on        = { transition = 'onTransition'       }
  }
end

function Config:configureInitTransition(init)
    local t = {}
    if type(init) == 'string' then
      t = mixin(t, self.defaults.init)
      t.to = init
      t.active = true
      return self:mapTransition(t)
    elseif typeof(init) == 'table' then
      t = mixin(t, self.defaults.init, init)
      t.active = true
      return self:mapTransition(t)
    else 
      self:addState(self.defaults.init.from)
      return self.defaults.init
    end
end

function Config:configureData(data) 
  if type(data) == 'function' then
    return data
  elseif type(data) == 'table' then
    return function() return data end
  else
    return function() return {} end
  end
end

function Config:configureMethods(methods) 
  return methods or {}
end

function Config:configureTransitions(transitions)
  local wildcard = self.defaults.wildcard 
  local transition, from, to
  for n=1,#transitions do
    transition = transitions[n]
    from  = type(transition.from) == 'table' and transition.from or {transition.from or wildcard}
    to    = transition.to or wildcard
    for i=1,#from do
      self:mapTransition({ name= transition.name, from= from[i], to=to })
    end
  end
end

function Config:addState(name)
    if not self.map[name] then
      table.insert(self.states,name)
      self:addStateLifecycleNames(name)
      self.map[name] = {}
    end
end

function Config:addStateLifecycleNames(name)
  self.lifecycle.onEnter[name] = Camelize.prepended('onEnter', name)
  self.lifecycle.onLeave[name] = Camelize.prepended('onLeave', name)
  self.lifecycle.on[name]      = Camelize.prepended('on',      name)
end

function Config:addTransition(name) 
  if not isInTable(self.transitions,name) then
    table.insert(self.transitions,name)
    self:addTransitionLifecycleNames(name)
  end
end

function Config:addTransitionLifecycleNames(name) 
    self.lifecycle.onBefore[name] = Camelize.prepended('onBefore', name)
    self.lifecycle.onAfter[name]  = Camelize.prepended('onAfter',  name)
    self.lifecycle.on[name]       = Camelize.prepended('on',       name)
end

function Config:mapTransition(transition) 
  local name = transition.name
  local from = transition.from
  local to   = transition.to
  self:addState(from)
  if type(to) ~= 'function' then
    self:addState(to)
  end
  self:addTransition(name)
  self.map[from][name] = transition
  return transition
end

function Config:transitionFor(state, transition) 
  local wildcard = self.defaults.wildcard
  return self.map[state][transition] or
         self.map[wildcard][transition]
end

function Config:transitionsFor(state) 
  local wildcard = self.defaults.wildcard
  local t = {}
  for _,v in pairs(self.map[state]) do
    table.insert(t,v)
  end
  for _,v in pairs(self.map[wildcard]) do
    table.insert(t,v)
  end
  return t
end

function Config:allStates() 
  return self.states
end

function Config:allTransitions()
  return self.transitions
end

return Config