local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local tabler = require 'nelua.utils.tabler'
local metamagic = require 'nelua.utils.metamagic'
local iters = require 'nelua.utils.iterators'
local Attr = require 'nelua.attr'
local ASTNode = require 'nelua.astnode'
local config = require 'nelua.configer'.get()
local shapetypes = require 'nelua.thirdparty.tableshape'.types

local ASTBuilder = class()

local function get_astnode_shapetype(nodeklass)
  return shapetypes.custom(function(val)
    if class.is(val, nodeklass) then return true end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function ASTBuilder:_init()
  self.nodes = { Node = ASTNode }
  self.shapetypes = { node = { Node = get_astnode_shapetype(ASTNode) } }
  self.shapes = { Node = shapetypes.shape {} }
  self.aster = {}
  metamagic.setmetaindex(self.shapetypes, shapetypes)
end

function ASTBuilder:register(tag, shape)
  shape.attr = shapetypes.table:is_optional()
  shape.uid = shapetypes.number:is_optional()
  shape = shapetypes.shape(shape)
  local klass = class(ASTNode)
  klass.tag = tag
  klass.nargs = #shape.shape
  self.shapetypes.node[tag] = get_astnode_shapetype(klass)
  self.shapes[tag] = shape
  self.nodes[tag] = klass
  self.aster[tag] = function(params)
    local nargs = math.max(klass.nargs, #params)
    local node = self:create(tag, table.unpack(params, 1, nargs))
    for k,v in iters.spairs(params) do
      node[k] = v
    end
    return node
  end
  return klass
end

function ASTBuilder:create(tag, ...)
  local klass = self.nodes[tag]
  if not klass then
    errorer.errorf("AST with name '%s' is not registered", tag)
  end
  local node = klass(...)
  if config.check_ast_shape then
    local shape = self.shapes[tag]
    local ok, err = shape(node)
    errorer.assertf(ok, 'invalid shape while creating AST node "%s": %s', tag, err)
  end
  return node
end

local genuid = ASTNode.genuid

function ASTBuilder:_create(tag, pos, src, ...)
  local node = setmetatable({
    pos = pos,
    src = src,
    uid = genuid(),
    attr = setmetatable({}, Attr),
  }, self.nodes[tag])
  for i=1,select('#', ...) do
    node[i] = select(i, ...)
  end
  return node
end

function ASTBuilder:clone()
  local clone = ASTBuilder()
  tabler.update(clone.nodes, self.nodes)
  tabler.update(clone.shapes, self.shapes)
  tabler.update(clone.shapetypes, self.shapetypes)
  return clone
end

return ASTBuilder
