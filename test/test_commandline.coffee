#
# Tests for the command line tool.
#

path = require 'path'
fs = require 'fs'
vows = require 'vows'
assert = require 'assert'
{spawn, exec} = require 'child_process'
coffeelint = require path.join('..', 'lib', 'coffeelint')


# The path to the command line tool.
coffeelintPath = path.join('bin', 'coffeelint')

# Run the coffeelint command line with the given
# args. Callback will be called with (error, stdout,
# stderr)
commandline = (args, callback) ->
    exec("#{coffeelintPath} #{args.join(" ")}", callback)


process.env.HOME = ""
process.env.HOMEPATH = ""
process.env.USERPROFILE = ""
process.env.COFFEELINT_CONFIG = ""

# Custom rules are loaded by module name. Using a relative path in the test is
# an unrealistic example when rules can be installed with `npm install -g
# some-custom-rule`. This will setup a fake version of node_modules to a
# relative path doesn't have to be used.
process.env.NODE_PATH += ":" + path.resolve( __dirname,
    "fixtures/mock_node_modules/")

vows.describe('commandline').addBatch({

    'with no args' :

        topic : () ->
            commandline [], this.callback
            return undefined

        'shows usage' : (error, stdout, stderr) ->
            assert.isNotNull(error)
            assert.notEqual(error.code, 0)
            assert.include(stderr, "Usage")
            assert.isEmpty(stdout)

    'version' :
        topic : () ->
            commandline ["--version"], this.callback
            return undefined

        'exists' : (error, stdout, stderr) ->
            assert.isNull(error)
            assert.isEmpty(stderr)
            assert.isString(stdout)
            assert.include(stdout, coffeelint.VERSION)

    'with clean source' :

        topic : () ->
            args = [
                '--noconfig'
                'test/fixtures/clean.coffee'
            ]
            commandline args, this.callback
            return undefined

        'passes' : (error, stdout, stderr) ->
            assert.isNull(error)
            assert.include(stdout, '0 errors and 0 warnings')
            assert.isEmpty(stderr)

    'with failing source' :

        topic : () ->
            args = [
                '--noconfig'
                'test/fixtures/fourspaces.coffee'
            ]
            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNotNull(error)
            assert.include(stdout.toLowerCase(), 'line')

    'with findconfig and local coffeelint.json' :

        topic : () ->
            args = [
                'test/fixtures/findconfigtest/sevenspaces.coffee'
            ]
            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNull(error)

    'with findconfig and  local package.json' :

        topic : () ->
            args = [
                'test/fixtures/findconfigtest/package/sixspaces.coffee'
            ]
            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNull(error)

    'with custom configuration' :

        topic : () ->
            args = [
                '-f'
                'test/fixtures/fourspaces.json'
                'test/fixtures/fourspaces.coffee'
            ]

            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNull(error)

    'with --rule parameter for a custom plugin':
        topic : () ->
            args = [
                '--rules'
                # It's up to NodeJS to resolve the actual path. The top of the
                # file modifies NODE_PATH so this can look like a 3rd party
                # module.
                "he_who_must_not_be_named"
                'test/fixtures/custom_rules/voldemort.coffee'
            ]

            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNotNull(error)
            assert.include(stdout.toLowerCase(), 'forbidden variable name')

    'with `module` specified for a specific rule':
        topic : () ->
            args = [
                '-f'
                'test/fixtures/custom_rules/rule_module.json'
                'test/fixtures/custom_rules/voldemort.coffee'
            ]

            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNotNull(error)
            assert.include(stdout.toLowerCase(), 'forbidden variable name')

    'with multiple sources'  :

        topic : () ->
            args = [
                '--noconfig'
                '-f'
                'test/fixtures/fourspaces.json'
                'test/fixtures/fourspaces.coffee'
                'test/fixtures/clean.coffee'
            ]

            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNotNull(error)

    'with configuration file' :

        topic : () ->
            configPath = 'generated_coffeelint.json'
            configFile = fs.openSync configPath, 'w'
            commandline ['--makeconfig'], (error, stdout, stderr) =>
                fs.writeSync configFile, stdout
                assert.isNull(error)
                args = [
                    '-f'
                    configPath
                    'test/fixtures/clean.coffee'
                ]
                commandline args, (args...) =>
                    this.callback stdout, args...

            return undefined

        'works' : (config, error, stdout, stderr) ->
            assert.isNotNull(config)
            # This will throw an exception if it doesn't parse.
            JSON.parse config
            assert.isNotNull(stdout)
            assert.isNull(error)

    'does not fail on warnings' :

        topic : () ->
            args = [
                '-f'
                'test/fixtures/twospaces.warning.json'
                'test/fixtures/fourspaces.coffee'
            ]

            commandline args, this.callback
            return undefined

        'works' : (error, stdout, stderr) ->
            assert.isNull(error)

    'with broken source' :

        topic : () ->
            args = [
                '--noconfig'
                'test/fixtures/syntax_error.coffee'
            ]
            commandline args, this.callback
            return undefined

        'fails' : (error, stdout, stderr) ->
            assert.isNotNull(error)

    'recurses subdirectories' :

        topic : () ->
            args = [
                '--noconfig',
                '-r',
                'test/fixtures/clean.coffee',
                'test/fixtures/subdir'
            ]
            commandline args, this.callback
            return undefined

        'and reports errors' : (error, stdout, stderr) ->
            assert.isNotNull(error, "returned err")
            assert.include(stdout.toLowerCase(), 'line')

    'allows JSLint XML reporting' :

        # FIXME: Not sure how to unit test escaping w/o major refactoring
        topic : () ->
            args = [
                '-f'
                'coffeelint.json'
                'test/fixtures/cyclo_fail.coffee'
                '--jslint'
            ]
            commandline args, this.callback
            return undefined

        'Handles cyclomatic complexity check' : (error, stdout, stderr) ->
            assert.include(stdout.toLowerCase(), 'cyclomatic complexity')

    'using stdin':

        'with working string':
            topic: () ->
                exec("echo y = 1 | #{coffeelintPath} --noconfig --stdin",
                    this.callback)
                return undefined

            'passes': (error, stdout, stderr) ->
                assert.isNull(error)
                assert.isEmpty(stderr)
                assert.isString(stdout)
                assert.include(stdout, '0 errors and 0 warnings')

        'with failing string due to whitespace':
            topic: () ->
                exec("echo 'x = 1 '| #{coffeelintPath} --noconfig --stdin",
                    this.callback)
                return undefined

            'fails': (error, stdout, stderr) ->
                assert.isNotNull(error)
                assert.include(stdout.toLowerCase(), 'trailing whitespace')

    'literate coffeescript':

        'with working string':
            topic: () ->
                exec("echo 'This is Markdown\n\n    y = 1' | " +
                    "#{coffeelintPath} --noconfig --stdin --literate",
                    this.callback)
                return undefined

            'passes': (error, stdout, stderr) ->
                assert.isNull(error)
                assert.isEmpty(stderr)
                assert.isString(stdout)
                assert.include(stdout, '0 errors and 0 warnings')

        'with failing string due to whitespace':
            topic: () ->
                exec("echo 'This is Markdown\n\n    x = 1 \n    y=2'| " +
                    "#{coffeelintPath} --noconfig --stdin --literate",
                    this.callback)
                return undefined

            'fails': (error, stdout, stderr) ->
                assert.isNotNull(error)
                assert.include(stdout.toLowerCase(), 'trailing whitespace')

    'using environment config file':

        'with non existing enviroment set config file':
            topic: () ->
                args = [
                    'test/fixtures/clean.coffee'
                ]
                process.env.COFFEELINT_CONFIG = "not_existing_293ujff"
                commandline args, this.callback
                return undefined

            'passes': (error, stdout, stderr) ->
                assert.isNull(error)

        'with existing enviroment set config file':
            topic: () ->
                args = [
                    'test/fixtures/fourspaces.coffee'
                ]
                conf = "test/fixtures/fourspaces.json"
                process.env.COFFEELINT_CONFIG = conf
                commandline args, this.callback
                return undefined

            'passes': (error, stdout, stderr) ->
                assert.isNull(error)

        'with existing enviroment set config file + --noconfig':
            topic: () ->
                args = [
                    '--noconfig'
                    'test/fixtures/fourspaces.coffee'
                ]
                conf = "test/fixtures/fourspaces.json"
                process.env.COFFEELINT_CONFIG = conf
                commandline args, this.callback
                return undefined

            'fails': (error, stdout, stderr) ->
                assert.isNotNull(error)

    'reports using basic reporter':
        'with option q set':
            'and no errors occured':
                topic: () ->
                    args = [ '-q', '--noconfig', 'test/fixtures/clean.coffee' ]
                    commandline args, this.callback
                    return undefined

                'no output': (err, stdout, stderr) ->
                    assert.isEmpty(stdout)

            'and errors occured':
                topic: () ->
                    args = [ '-q', 'test/fixtures/syntax_error.coffee' ]
                    commandline args, this.callback
                    return undefined

                'output': (error, stdout, stderr) ->
                    console.log(error, stdout, stderr)
                    assert.isNotEmpty(stdout)

        'with option q not set':
            'and no errors occured':
                topic: () ->
                    args = [ 'test/fixtures/clean.coffee' ]
                    commandline args, this.callback
                    return undefined

                'output': (err, stdout, stderr) ->
                    assert.isNotEmpty(stdout)

            'and errors occured':
                topic: () ->
                    args = [ 'test/fixtures/syntax_error.coffee' ]
                    commandline args, this.callback
                    return undefined

                'output': (error, stdout, stderr) ->
                    assert.isNotEmpty(stdout)

}).export(module)
