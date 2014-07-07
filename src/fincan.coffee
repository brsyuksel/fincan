
require 'colors'

fs = require 'fs'
path = require 'path'
vm = require 'vm'

COFFEE_PATH = 'node_modules/coffee-script/lib/coffee-script/'

###
basic startsWith endsWith methods for strings
###
String::startsWith ?= (s) -> @slice(0, s.length) is s
String::endsWith ?= (s) -> s is '' or @slice(-s.length) is s

###
searches user-defined utilities functions file and includes it
###
require_userdef_utilities = ->
  cwd = process.cwd()
  files = fs.readdirSync cwd
  util_file = do ->
    file = null
    files.some (e) ->
      res = !!~[".utilities.coffee", ".utilities.js"].indexOf e
      file ?= e if res
      res
    file

  if util_file?
    console.log "#{util_file} has been found".green.bold
    require 'coffee-script/register' if util_file.endsWith '.coffee'
    require "#{cwd}/#{util_file}"
  else
    console.log "utilites file can not be found".red.bold
    no

###
realpath for coffee-script files
###
coffee_files_realpath = (name) ->
  fs.realpathSync path.join path.dirname(__filename), '../', COFFEE_PATH,
  name + '.js' if not name.endsWith '.js'

###
require workaround for coffee-script local files 
###
require_local = (m) ->
  require if not m.startsWith './' then m else coffee_files_realpath m

###
creates new context for script run-time
###
new_context = (requirefn=require) ->
  ct_module = new module.__proto__.constructor
  console: console
  module: ct_module
  exports: ct_module.exports
  process: process
  require: requirefn

###
patches coffee-script/nodes.js
###
patch_nodes_js = (utilities) ->
  nodes = require coffee_files_realpath 'nodes'
  scope = require(coffee_files_realpath 'scope').Scope

  # and the dirty side of all
  fragmentsToText = (fragments) ->
    (fragment.code for fragment in fragments).join('')

  utility = (name) ->
    scope.root.assign "__#{name}", utilities[name]
    "__#{name}"

  # __extends function
  if utilities.extends?
    nodes.Extends::compileToFragments = (o) ->
      new nodes.Call(
        new nodes.Value(new nodes.Literal utility 'extends'),
        [@child, @parent]
      ).compileToFragments o

  # __bind function
  if utilities.bind?
    nodes.Class::addBoundFunctions = (o) ->
      for bvar in @boundFuncs
        lhs = (new nodes.Value (new nodes.Literal "this"), [new nodes.Access bvar]).compile o
        @ctor.body.unshift new nodes.Literal "#{lhs} = #{utility 'bind'}(#{lhs}, this)"
      return

  # modulo
  if utilities.modulo?
    nodes.Op::compileModulo = (o) ->
      mod = new nodes.Value new nodes.Literal utility 'modulo'
      new nodes.Call(mod, [@first, @second]).compileToFragments o
  
  # indexOf
  if utilities.indexOf?
    nodes.In::compileLoopTest = (o) ->
      LEVEL_LIST = 3
      [sub, ref] = @object.cache o, LEVEL_LIST
      fragments = [].concat @makeCode(utility('indexOf') + ".call("), @array.compileToFragments(o, LEVEL_LIST),
        @makeCode(", "), ref, @makeCode(") " + if @negated then '< 0' else '>= 0')
      return fragments if fragmentsToText(sub) is fragmentsToText(ref)
      fragments = sub.concat @makeCode(', '), fragments
      if o.level < LEVEL_LIST then fragments else @wrapInBraces fragments
  ###
  TODO:
    hasProp
    slice
  ###
  nodes

###
patches coffee-script/coffee-script.js
###
patch_coffee_script_js = (nodes) ->
  coffee_script_js = fs.readFileSync coffee_files_realpath 'coffee-script'
  context = new_context (m) ->
    if m is './nodes'
      nodes
    else
      require_local m
  script = vm.createScript coffee_script_js
  script.runInNewContext vm.createContext context
  context

###
patches coffee-script/command.js
###
patch_command_js = (coffee_script) ->
  command_js = fs.readFileSync coffee_files_realpath 'command'
  command_js += 'exports.run();'
  context = new_context (m) ->
    if m is './coffee-script'
      coffee_script
    else
      require_local m
  script = vm.createScript command_js
  script.runInNewContext vm.createContext context


utilities = require_userdef_utilities()
if !!utilities
  patch_command_js patch_coffee_script_js(patch_nodes_js utilities).exports
else
  require(coffee_files_realpath 'command').run()