// Generated by CoffeeScript 2.0.0-beta4
void function () {
  var assert, async, basenameWithoutExtension, contents, dir, fs, fse, glob, hogan, modulePrefixedBasenameWithoutExtension, name, noErr, path, readAndCompileTemplates, regexpEscape, resultEquals, setup, sources, templates;
  fs = require('fs');
  hogan = require('hogan.js');
  async = require('async');
  glob = require('glob');
  module.exports = setup = function (param$) {
    var baseDirectory, cache$, compiledCache, load, modulesDirectory, reload, render, source, sourceCache;
    {
      cache$ = param$;
      baseDirectory = cache$.baseDirectory;
      modulesDirectory = cache$.modulesDirectory;
      reload = cache$.reload;
    }
    if (null != baseDirectory)
      baseDirectory;
    else
      baseDirectory = path.join(__dirname, 'templates');
    if (null != modulesDirectory)
      modulesDirectory;
    else
      modulesDirectory = path.join(__dirname, 'modules');
    sourceCache = null;
    compiledCache = null;
    if (null != reload)
      reload;
    else
      reload = process.env.NODE_ENV === 'development';
    source = function (name, cb) {
      return load(function (err, compiledTemplates, sourceTemplates) {
        var sourceTemplate;
        if (null != err)
          return cb(err);
        if (name === '*')
          return cb(noErr, sourceTemplates);
        sourceTemplate = sourceTemplates[name];
        if (!(null != sourceTemplate))
          return cb(new Error('No template named: ' + name));
        return cb(noErr, sourceTemplate);
      });
    };
    render = function (name, view, cb) {
      return load(function (err, compiledTemplates, sourceTemplates) {
        var compiledTemplate, html;
        if (null != err)
          return cb(err);
        compiledTemplate = compiledTemplates[name];
        if (!(null != compiledTemplate))
          return cb(new Error('No template named: ' + name));
        try {
          html = compiledTemplate.render(view, compiledTemplates);
          return cb(noErr, html);
        } catch (e$) {
          err = e$;
          return cb(err);
        }
      });
    };
    load = function (cb) {
      if (null != compiledCache)
        return cb(noErr, compiledCache, sourceCache);
      return async.parallel({
        templates: function (cb) {
          return readAndCompileTemplates(baseDirectory, '*.mustache', basenameWithoutExtension, cb);
        },
        moduleTemplates: function (cb) {
          if (!(null != modulesDirectory))
            return cb(noErr, {});
          return readAndCompileTemplates(modulesDirectory, '**/*.mustache', modulePrefixedBasenameWithoutExtension(modulesDirectory), cb);
        }
      }, function (err, results) {
        var compiledTemplates, k, sourceTemplates, v;
        if (null != err)
          return cb(err);
        compiledTemplates = {};
        sourceTemplates = {};
        for (k in results.templates.compiledTemplates) {
          v = results.templates.compiledTemplates[k];
          compiledTemplates[k] = v;
        }
        for (k in results.moduleTemplates.compiledTemplates) {
          v = results.moduleTemplates.compiledTemplates[k];
          compiledTemplates[k] = v;
        }
        for (k in results.templates.sourceTemplates) {
          v = results.templates.sourceTemplates[k];
          sourceTemplates[k] = v;
        }
        for (k in results.moduleTemplates.sourceTemplates) {
          v = results.moduleTemplates.sourceTemplates[k];
          sourceTemplates[k] = v;
        }
        if (!reload)
          compiledCache = compiledTemplates;
        if (!reload)
          sourceCache = sourceTemplates;
        return cb(noErr, compiledTemplates, sourceTemplates);
      });
    };
    return {
      render: render,
      source: source
    };
  };
  readAndCompileTemplates = function (dir, globFilter, nameFromFilenameFn, cb) {
    return async.waterfall([
      function (cb) {
        return glob(dir + '/' + globFilter, cb);
      },
      function (fileNames, cb) {
        return async.map(fileNames, fs.readFile, function (err, fileContents) {
          return cb(err, fileNames, fileContents);
        });
      }
    ], function (err, fileNames, fileContents) {
      var fileName, i, name, result;
      if (null != err)
        return cb(err);
      result = {
        compiledTemplates: {},
        sourceTemplates: {}
      };
      for (var i$ = 0, length$ = fileNames.length; i$ < length$; ++i$) {
        fileName = fileNames[i$];
        i = i$;
        name = nameFromFilenameFn(fileName);
        result.compiledTemplates[name] = hogan.compile(fileContents[i].toString('utf8'));
        result.sourceTemplates[name] = fileContents[i].toString('utf8');
      }
      return cb(noErr, result);
    });
  };
  noErr = null;
  basenameWithoutExtension = function (fileName) {
    return fileName.match(/.+\/(.+)\..+\.mustache$/)[1];
  };
  regexpEscape = function (s) {
    return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
  };
  modulePrefixedBasenameWithoutExtension = function (modulesDirectory) {
    return function (fileName) {
      var cache$, dir, moduleName, pattern, templateName;
      dir = modulesDirectory.replace(/\/$/, '');
      pattern = regexpEscape(dir) + '\\/(.+)\\/(.+)\\..+\\.mustache$';
      cache$ = fileName.match(pattern).slice(1, +2 + 1 || 9e9);
      moduleName = cache$[0];
      templateName = cache$[1];
      if (templateName === 'main') {
        return moduleName;
      } else {
        return moduleName + '_' + templateName;
      }
    };
  };
  if (process.argv[1] === __filename) {
    assert = require('assert');
    assert.equal('foo', basenameWithoutExtension('/tmp/foo.html.mustache'));
    assert.equal('baz', modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/main.html.mustache'));
    assert.equal('baz/nested', modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/nested/main.html.mustache'));
    assert.equal('baz/nested/a/b/c', modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/nested/a/b/c/main.html.mustache'));
    assert.equal('baz/nested/a/b/c', modulePrefixedBasenameWithoutExtension('/tmp/modules/')('/tmp/modules/baz/nested/a/b/c/main.html.mustache'));
    assert.equal('baz_qux', modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/qux.html.mustache'));
    assert.equal('baz/nested/abc_qux', modulePrefixedBasenameWithoutExtension('/tmp/modules')('/tmp/modules/baz/nested/abc/qux.html.mustache'));
    fse = require('fs-extra');
    path = require('path');
    dir = '/tmp/' + path.basename(__filename) + '-test';
    fse.removeSync(dir);
    fse.mkdirSync(dir);
    templates = setup({ baseDirectory: dir });
    sources = {
      foo: '{{foo}}',
      bar: '{{bar}}',
      partials: '{{>foo}}{{>bar}}'
    };
    for (name in sources) {
      contents = sources[name];
      fse.writeFileSync('' + dir + '/' + name + '.html.mustache', contents, 'utf8');
    }
    resultEquals = function (expected, next) {
      return function (err, html) {
        assert.ifError(err);
        assert.equal(expected, html);
        return next();
      };
    };
    async.series([
      function (next) {
        var view;
        view = { foo: 'value of foo' };
        return templates.render('foo', view, resultEquals('value of foo', next));
      },
      function (next) {
        var view;
        view = {
          foo: 'a',
          bar: 'b'
        };
        return templates.render('partials', view, resultEquals('ab', next));
      },
      function (next) {
        return templates.source('foo', resultEquals(sources.foo, next));
      },
      function (next) {
        return templates.source('*', function (err, sources) {
          assert.equal(typeof sources, 'object');
          assert.equal(sources.foo, '{{foo}}');
          return next();
        });
      }
    ], function (err) {
      var bazModuleDir, bazModuleSources, modulesDir;
      assert.ifError(err);
      modulesDir = dir + '-modules';
      bazModuleDir = modulesDir + '/baz';
      fse.mkdirSync(bazModuleDir);
      templates = setup({
        baseDirectory: dir,
        modulesDirectory: modulesDir
      });
      bazModuleSources = {
        main: '{{>baz_qux}}',
        qux: 'contents of baz_qux module template'
      };
      for (name in bazModuleSources) {
        contents = bazModuleSources[name];
        fse.writeFileSync('' + bazModuleDir + '/' + name + '.html.mustache', contents, 'utf8');
      }
      templates.compiledCache = null;
      templates.sourceCache = null;
      return templates.render('baz', {}, function (err, html) {
        assert.ifError(err);
        assert.equal('contents of baz_qux module template', html);
        console.log('ok');
        return process.exit();
      });
    });
  }
}.call(this);
