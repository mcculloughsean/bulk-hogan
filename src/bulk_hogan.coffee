# Template Rendering
# ==================
#
# Produces html from some view object by rendering it via some mustache
# implementation.
#
# For example:
#
#   templates.render 'layout', { body: "body html" }, (err, html) ->
#     throw err if err?
#     console.log html
#
# The `render` method calls `load` internally which is responsible for reading
# all templates from disk and then compiling them. In production you should call
# `load` explicitly during server initialization to ensure that the first
# request(s) aren't bogged down with IO.
#
# Templates can also be loaded from special "module" folders. For example if you
# had a project directory structure like:
#
#     /modules/
#       /deal
#         main.html.mustache
#         detail.html.mustache
#     /templates
#       layout.html.mustache
#
# And you tell `templates` where the module folders are:
#
#     templates.modulesDir = projectDir + '/modules'
#
# Then those templates will loaded and their name's prefixed with the module
# name (except `main.html.mustache` which will be named after the module):
#
#     templates.render 'deal', ...        # renders /modules/deal/main.html.mustache
#     templates.render 'deal_detail', ... # renders /modules/deal/detail.html.mustache
#
#
# You can also get the source of a template by calling
#
#     # one template
#     templates.source 'deal', (err, mustache) ->
#       mustache == "{{deal..."
#
#     # all template
#     templates.source '*', (err, mustache) ->
#       mustache.deal == "{{deal..."
#

fs    = require 'fs'
hogan = require 'hogan.js'
async = require 'async'
glob  = require 'glob'

module.exports = setup = ({baseDirectory, modulesDirectory, reload}) ->

  # Where to look for template files
  baseDirectory ?= path.join __dirname, 'templates'
  modulesDirectory ?= path.join __dirname, 'modules'

  # Memory location used to store the uncompiled templates
  sourceCache = null

  # Memory location used to store the compiled templates
  compiledCache = null

  # When `reload` is true, *all* templates are re-read from disk then
  # re-compiled every time render is called. You only ever want this behavior
  # during development. And even then, it's an optimization over just restarting
  # the entire server process.
  reload ?= process.env.NODE_ENV is 'development'

  ## Interface Functions

  # Return the source of a template
  source = (name, cb) ->
    load (err, compiledTemplates, sourceTemplates) ->
      return cb(err) if err?
      return cb noErr, sourceTemplates if name is '*'
      sourceTemplate = sourceTemplates[name]
      return cb(new Error "No template named: #{name}") unless sourceTemplate?
      cb noErr, sourceTemplate

  # Render a mustache template
  render = (name, view, cb) ->
    load (err, compiledTemplates, sourceTemplates) ->
      return cb(err) if err?
      compiledTemplate = compiledTemplates[name]
      return cb(new Error "No template named: #{name}") unless compiledTemplate?
      try
        html = compiledTemplate.render view, compiledTemplates
        cb noErr, html
      catch err
        cb err

  load = (cb) ->
    return cb(noErr, compiledCache, sourceCache) if compiledCache?
    async.parallel {
      templates: (cb) =>
        readAndCompileTemplates baseDirectory,  '*.mustache', basenameWithoutExtension, cb
      moduleTemplates: (cb) =>
        return cb(noErr, {}) unless modulesDirectory?
        readAndCompileTemplates modulesDirectory,  '**/*.mustache', modulePrefixedBasenameWithoutExtension(modulesDirectory), cb
    }, (err, results) =>
      return cb(err) if err?
      compiledTemplates = {}
      sourceTemplates = {}

      compiledTemplates[k] = v for k,v of results.templates.compiledTemplates
      compiledTemplates[k] = v for k,v of results.moduleTemplates.compiledTemplates
      sourceTemplates[k] = v for k,v of results.templates.sourceTemplates
      sourceTemplates[k] = v for k,v of results.moduleTemplates.sourceTemplates

      compiledCache = compiledTemplates unless reload
      sourceCache = sourceTemplates unless reload

      cb noErr, compiledTemplates, sourceTemplates

  return { render, source }


# Given a directory, glob filter, and function to convert a pathname into a
# template name, calls the callback with a hashmap of template names and
# compiled templates
readAndCompileTemplates = (dir, globFilter, nameFromFilenameFn, cb) ->
  async.waterfall [
    # find template files
    (cb) -> glob dir + '/' + globFilter, cb
    # read file contents
    (fileNames, cb) ->
      async.map fileNames, fs.readFile, (err, fileContents) ->
        cb err, fileNames, fileContents
  ], (err, fileNames, fileContents) ->
    return cb(err) if err?
    result =
      compiledTemplates: {}
      sourceTemplates: {}

    for fileName, i in fileNames
      # extract template name
      name = nameFromFilenameFn fileName
      # compile template
      result.compiledTemplates[name] = hogan.compile fileContents[i].toString 'utf8'
      result.sourceTemplates[name] = fileContents[i].toString 'utf8'
    # return hashmap of template names and compiled contents
    cb noErr, result

# An aesthetic tweak, `cb(noErr)` reveals more intent than `cb(null)`
noErr = null

basenameWithoutExtension = (fileName) ->
  fileName.match(/// .+ \/ (.+) \. .+ \.mustache $ ///)[1]

regexpEscape = (s) -> s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')

modulePrefixedBasenameWithoutExtension = (modulesDirectory) ->
  (fileName) ->
    dir = modulesDirectory.replace /\/$/, ''
    pattern = regexpEscape(dir) + '\\/(.+)\\/(.+)\\..+\\.mustache$'
    [moduleName, templateName] = fileName.match(pattern)[1..2]
    if templateName is 'main' then moduleName else moduleName + '_' + templateName


# Tests
# =====
#
# Run these with `coffee templates.coffee`


if process.argv[1] is __filename

  assert = require 'assert'

  ## Unit tests
  assert.equal "foo", basenameWithoutExtension('/tmp/foo.html.mustache')
  assert.equal "baz", modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/main.html.mustache')
  assert.equal "baz/nested", modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/nested/main.html.mustache')
  assert.equal "baz/nested/a/b/c", modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/nested/a/b/c/main.html.mustache')
  assert.equal "baz/nested/a/b/c", modulePrefixedBasenameWithoutExtension('/tmp/modules/')('/tmp/modules/baz/nested/a/b/c/main.html.mustache')
  assert.equal "baz_qux", modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/qux.html.mustache')
  assert.equal "baz/nested/abc_qux", modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/nested/abc/qux.html.mustache')

  ## Integration tests
  fse  = require 'fs-extra'
  path = require 'path'

  dir = "/tmp/#{path.basename __filename}-test"
  fse.removeSync dir
  fse.mkdirSync dir

  templates = setup { baseDirectory: dir }

  sources =
    foo: "{{foo}}"
    bar: "{{bar}}"
    partials: "{{>foo}}{{>bar}}"

  for name, contents of sources
    fse.writeFileSync "#{dir}/#{name}.html.mustache", contents, 'utf8'

  resultEquals = (expected, next) ->
    (err, html) ->
      assert.ifError err
      assert.equal expected, html
      next()

  async.series [

    # no partials
    (next) ->
      view = { foo: 'value of foo' }
      templates.render 'foo', view, resultEquals('value of foo', next)

    # with partials
    (next) ->
      view = { foo: 'a', bar: 'b' }
      templates.render 'partials', view, resultEquals('ab', next)

    # Get one template's source
    (next) ->
      templates.source 'foo', resultEquals(sources.foo, next)

    # Get all templates' source
    (next) ->
      templates.source '*', (err, sources) ->
        assert.equal typeof sources, 'object'
        assert.equal sources.foo, "{{foo}}"
        next()


  ], (err) ->
    assert.ifError err

    # With modules dir
    modulesDir = dir + '-modules'
    bazModuleDir = modulesDir + '/baz'
    fse.mkdirSync bazModuleDir

    templates = setup { baseDirectory: dir, modulesDirectory: modulesDir }

    bazModuleSources =
      main: "{{>baz_qux}}"
      qux:    "contents of baz_qux module template"

    for name, contents of bazModuleSources
      fse.writeFileSync "#{bazModuleDir}/#{name}.html.mustache", contents, 'utf8'

    templates.compiledCache = null # reset cache, force reload
    templates.sourceCache = null

    templates.render 'baz', {}, (err, html) ->
      assert.ifError err
      assert.equal "contents of baz_qux module template", html

      console.log "ok"
      process.exit()
