path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'
nodeVersion = require('./config.json').nodeVersion

describe 'apm rebuild', ->
  [server, originalPathEnv] = []

  beforeEach ->
    spyOnToken()
    silenceOutput()

    app = express()
    app.get "/node/#{nodeVersion}/node-#{nodeVersion}.tar.gz", (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-source', "node-#{nodeVersion}.tar.gz")
    app.get "/node/#{nodeVersion}/node-#{nodeVersion}-headers.tar.gz", (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-source', "node-#{nodeVersion}-headers.tar.gz")
    app.get "/node/#{nodeVersion}/node.lib", (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-source', 'node.lib')
    app.get "/node/#{nodeVersion}/x64/node.lib", (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-source', 'node_x64.lib')
    app.get "/node/#{nodeVersion}/SHASUMS256.txt", (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-source', 'SHASUMS256.txt')

    server = http.createServer(app)

    live = false
    server.listen 3000, '127.0.0.1', ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_ELECTRON_URL = "http://localhost:3000/node"
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
      process.env.ATOM_ELECTRON_VERSION = "#{nodeVersion}"
      process.env.ATOM_RESOURCE_PATH = temp.mkdirSync('atom-resource-path-')

      originalPathEnv = process.env.PATH
      process.env.PATH = ""
      live = true
    waitsFor -> live

  afterEach ->
    process.env.PATH = originalPathEnv

    done = false
    server.close -> done = true
    waitsFor -> done

  it "rebuilds all modules when no module names are specified", ->
    packageToRebuild = path.join(__dirname, 'fixtures/package-with-native-deps')

    process.chdir(packageToRebuild)
    callback = jasmine.createSpy('callback')
    apm.run(['rebuild'], callback)

    waitsFor 'waiting for rebuild to complete', 600000, ->
      callback.callCount is 1

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeUndefined()

  it "rebuilds the specified modules", ->
    packageToRebuild = path.join(__dirname, 'fixtures/package-with-native-deps')

    process.chdir(packageToRebuild)
    callback = jasmine.createSpy('callback')
    apm.run(['rebuild', 'native-dep'], callback)

    waitsFor 'waiting for rebuild to complete', 600000, ->
      callback.callCount is 1

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeUndefined()
