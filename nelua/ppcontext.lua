local traits = require 'nelua.utils.traits'
local class = require 'nelua.utils.class'
local bn = require 'nelua.utils.bn'
local typedefs = require 'nelua.typedefs'
local VisitorContext = require 'nelua.analyzercontext'
local Attr = require 'nelua.attr'

local PPContext = class(VisitorContext)

function PPContext:_init(visitors, context)
  VisitorContext._init(self, visitors)
  self.context = context
  self.registry = {}
  self.statnodes = nil
  self.statnodestack = {}
end

function PPContext:push_statnodes(statnodes)
  if not statnodes then
    statnodes = {}
  end
  local statnodestack = self.statnodestack
  statnodestack[#statnodestack+1] = self.statnodes
  self.statnodes = statnodes
  return statnodes
end

function PPContext:pop_statnodes()
  local statnodestack = self.statnodestack
  local index = #statnodestack
  self.statnodes = statnodestack[index]
  statnodestack[index] = nil
end

function PPContext:add_statnode(node, clone)
  if clone then
    node = node:clone()
  end
  local statnodes = self.statnodes
  if statnodes.addindex then
    local addindex = statnodes.addindex
    statnodes.addindex = addindex + 1
    table.insert(self.statnodes, addindex, node)
  else
    self.statnodes[#statnodes+1] = node
  end
  self.context:traverse_node(node)
end

function PPContext.toname(_, val, orignode)
  orignode:assertraisef(traits.is_string(val),
    'unable to convert preprocess value of type "%s" to a compile time name', type(val))
  return val
end

function PPContext:tovalue(val, orignode)
  local node
  local aster = self.context.parser.astbuilder.aster
  if traits.is_astnode(val) then
    node = val
  elseif traits.is_type(val) then
    node = aster.Type{'auto'}
    -- inject persistent parsed type
    local pattr = Attr({
      type = typedefs.primtypes.type,
      value = val
    })
    node.attr:merge(pattr)
    node.pattr = pattr
  elseif traits.is_string(val) then
    node = aster.String{val}
  elseif traits.is_symbol(val) then
    node = aster.Id{val.name}
    local pattr = Attr({
      foreignsymbol = val
    })
    node.attr:merge(pattr)
    node.pattr = pattr
  elseif bn.isnumeric(val) then
    local num = bn.parse(val)
    local neg = false
    if bn.isneg(num) then
      num = bn.abs(num)
      neg = true
    end
    if bn.isintegral(num) then
      node = aster.Number{'dec', bn.todec(num)}
    else
      local snum = bn.todecsci(num)
      local int, frac, exp = bn.splitdecsci(snum)
      node = aster.Number{'dec', int, frac, exp}
    end
    if neg then
      node = aster.UnaryOp{'unm', node}
    end
  elseif traits.is_boolean(val) then
    node = aster.Boolean{val}
  --TODO: table, nil
  else
    orignode:raisef('unable to convert preprocess value of type "%s" to a const value', type(val))
  end
  node.src = orignode.src
  node.pos = orignode.pos
  return node
end

function PPContext:getregistryindex(what)
  local registry = self.registry
  local regindex = registry[what]
  if not regindex then
    table.insert(registry, what)
    regindex = #registry
    registry[what] = regindex
  end
  return regindex
end

return PPContext
