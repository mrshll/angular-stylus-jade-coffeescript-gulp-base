# ------------------------------------------------------------------------------
# Load in modules
# ------------------------------------------------------------------------------
gulp = require 'gulp'
$ = require('gulp-load-plugins')()

fs = require 'fs'
cached = require 'gulp-cached'
runSequence = require 'run-sequence'
mainBowerFiles = require 'main-bower-files'
nib = require 'nib'

ENV = process.env.NODE_ENV or 'development'

{config} = require 'rygr-util'
config.initialize 'config/*.json'

# ------------------------------------------------------------------------------
# Custom vars and methods
# ------------------------------------------------------------------------------
alertError = $.notify.onError (error) ->
  console.log 'alert error!'
  message = error?.message or error?.toString() or 'Something went wrong'
  "Error: #{ message }"

# ------------------------------------------------------------------------------
# Directory management
# ------------------------------------------------------------------------------
gulp.task 'clean', ->
  dir = config.client.build.root
  fs.mkdirSync dir unless fs.existsSync dir

  gulp.src("#{ dir }/*", read: false)
    .pipe($.plumber errorHandler: alertError)
    .pipe $.rimraf force: true

# ------------------------------------------------------------------------------
# Copy static assets
# ------------------------------------------------------------------------------
gulp.task 'public', ->
  gulp.src("#{ config.client.src.public }/**")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.root)
    .pipe gulp.dest config.client.build.root

gulp.task 'vendor-js', ->
  gulp.src(mainBowerFiles(debugging:true).concat ["#{ config.client.src.vendor }/**/*.js"])
    .pipe($.filter '**/*.js')
    .pipe($.order [
      '**/lodash.compat.js'
      '**/jquery.js'
      '**/jquery-address.js'
      '**/angular.js'
      '**/angular-*.js'
      '**/*.js'
    ])
    .pipe($.plumber errorHandler: alertError)
    .pipe($.concat 'vendor.js')
    .pipe($.if (ENV is 'production'), $.uglify(mangle: false))
    .pipe gulp.dest config.client.build.assets
    .pipe($.size())

gulp.task 'vendor-css', ->
  stylusFilter = $.filter '**/*.styl'

  gulp.src(mainBowerFiles().concat ["#{ config.client.src.vendor }/**/*.css"])
    .pipe($.filter ['**/*.styl', '**/*.css'])
    .pipe(stylusFilter)
    .pipe($.stylus
      'cache limit': 1
      set: ['compress']
      use: [nib()]
    )
    .pipe(stylusFilter.restore())
    .pipe($.plumber errorHandler: alertError)
    .pipe($.concat 'vendor.css')
    .pipe($.if (ENV is 'production'), $.minifyCss())
    .pipe(gulp.dest config.client.build.assets)
    .pipe($.size())

gulp.task 'vendor-etc', ->
  gulp.src(mainBowerFiles())
    .pipe($.filter ['**/*.swf'])
    .pipe(gulp.dest config.client.build.assets)
    .pipe($.size())

gulp.task 'images', ->
  gulp.src("#{ config.client.src.images }/**")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.assets)
    # .pipe($.imagemin())
    .pipe(gulp.dest config.client.build.assets)
    .pipe($.size())

# ------------------------------------------------------------------------------
# Compile assets
# ------------------------------------------------------------------------------
gulp.task 'scripts', ->
  coffeeFilter = $.filter '**/*.coffee'

  gulp.src("#{ config.client.src.scripts }/**/*.{js,coffee}")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.assets)
    .pipe($.preprocess context: ENV: ENV)
    .pipe(coffeeFilter)
    .pipe($.coffeelint optFile: './.coffeelintrc')
    .pipe($.coffeelint.reporter())
    .pipe($.coffee bare: true)
    .pipe(coffeeFilter.restore())
    .pipe($.concat 'app.js')
    .pipe($.if (ENV is 'production'), $.uglify(mangle: false))
    .pipe(gulp.dest config.client.build.assets)
    .pipe($.size())

gulp.task 'index', ->
  gulp.src("#{ config.client.src.root }/index.jade")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.preprocess context: ENV: ENV)
    .pipe($.jade
      pretty: true
      locals: config
    )
    .pipe(gulp.dest config.client.build.root)
    .pipe($.size())

gulp.task 'jade', ->
  gulp.src("#{ config.client.src.views }/**/*.jade")
    .pipe($.jade())
    .pipe($.ngHtml2js
      moduleName: 'appTemplates'
    )
    .pipe($.concat 'templates.js')
    .pipe(gulp.dest config.client.build.assets)
    .pipe($.size())

gulp.task 'stylus', ->
  delete require.cache[require.resolve 'gulp-stylus']
  $.stylus = require 'gulp-stylus'

  gulp.src("#{ config.client.src.stylesheets }/main.styl")
    .pipe($.stylus
      'cache limit': 1
      paths: [
        config.client.src.stylesheets
        config.client.build.assets
      ]
      use: [nib()]
      # import: ['components/*.styl', 'globals/*.styl']
    )
    .pipe($.autoprefixer
      browsers: ['last 2 versions'],
      cascade: false
    )
    .on 'error', (e) ->
      $.util.log(e.toString())
      this.emit('end')
    .pipe($.if (ENV is 'production'), $.minifyCss())
    .pipe(gulp.dest config.client.build.assets)
    .pipe($.size())

# ------------------------------------------------------------------------------
# Testing
# ------------------------------------------------------------------------------

gulp.task 'protractor', ->
  require('coffee-script/register')
  gulp.src('test/e2e/**/*.coffee')
    .pipe($.protractor.protractor configFile: 'protractor.conf.js')
    .on('error', (e) ->
      $.util.log(e.toString())
      this.emit('end')
    )

gulp.task 'test:e2e', ['protractor'], ->
  gulp.watch('test/e2e/**/*.coffee', ['protractor'])

# ------------------------------------------------------------------------------
# Server
# ------------------------------------------------------------------------------
gulp.task 'server', ->
  nodemon = require 'nodemon'

  nodemon
    script: config.server.main
    watch: config.server.root
    ext: 'js coffee json'

  nodemon
    .on('start', -> console.log 'Server has started')
    .on('quit', -> console.log 'Server has quit')
    .on('restart', (files) -> console.log 'Server restarted due to: ', files)

# ------------------------------------------------------------------------------
# Build
# ------------------------------------------------------------------------------
gulp.task 'build', (cb) ->
  sequence = [
    'clean'
    ['vendor-js', 'vendor-css', 'vendor-etc', 'scripts', 'jade', 'images', 'public', 'stylus', 'index']
    cb
  ]
  runSequence sequence...

# ------------------------------------------------------------------------------
# Deploy
# ------------------------------------------------------------------------------
gulp.task 'clean-deploy', ->
  dir = config.client.deploy.root
  fs.mkdirSync dir unless fs.existsSync dir

  gulp.src("#{ dir }/*", read: false)
    .pipe($.plumber errorHandler: alertError)
    .pipe $.rimraf force: true

gulp.task 'set-production', (cb) ->
  ENV = 'production'
  cb()

gulp.task 'set-staging', (cb) ->
  ENV = 'staging'
  cb()

gulp.task 'rev', ->
 gulp.src("#{ config.client.build.root }/**")
   .pipe($.revAll())
   .pipe(gulp.dest config.client.deploy.root)

aws =
  key: config.client.deploy.awsKey
  secret: config.client.deploy.awsSecret
  bucket: config.client.deploy.awsBucket
  region: config.client.deploy.awsRegion
  distributionId: config.client.deploy.awsDistributionId
  originAccessIdentity: config.client.deploy.awsOriginAccessIdentity

gulp.task 'deploy-assets', ->
  headers = 'Cache-Control': 'max-age=315360000, no-transform, public'
  publisher = $.awspublish.create(aws)
  gulp.src("#{ config.client.deploy.root }/**")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.awspublish.gzip())
    .pipe(publisher.publish headers)
    .pipe(publisher.cache())
    .pipe($.awspublish.reporter())

gulp.task 'deploy-index', ->
  headers = 'Cache-Control': 'max-age=10, no-transform, public'

  gulp.src("#{ config.client.deploy.root }/index.*\.html")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.awspublish.gzip())
    .pipe($.rename (path) ->
      path.basename = 'index'

      if ENV is 'production'
        path.extname = '.html.gz'
      else if ENV is 'staging'
        path.extname = '.stage.html.gz'

      path
    )
    .pipe($.s3(aws,
      headers: headers
    ))

gulp.task 'production', (cb) ->
  sequence = [
    'set-production'
    'clean-deploy'
    'build'
    'rev'
    'deploy-assets'
    'deploy-index'
    cb
  ]

  runSequence sequence...

gulp.task 'stage', (cb) ->
  sequence = [
    'set-staging'
    'clean-deploy'
    'build'
    'rev'
    'deploy-assets'
    'deploy-index'
    cb
  ]

  runSequence sequence...


# ------------------------------------------------------------------------------
# Watch
# ------------------------------------------------------------------------------
gulp.task 'watch', (cb) ->
  lr = $.livereload config.livereload.port

  gulp.watch("#{ config.client.build.root }/**")
    .on 'change', (file) ->
      lr.changed file.path

  gulp.watch "#{ config.client.src.root }/index.jade", ['index']
  gulp.watch "#{ config.client.src.views }/**/*.jade", ['jade']
  gulp.watch "#{ config.client.src.scripts }/**/*.{js,coffee}", ['scripts']
  gulp.watch "#{ config.client.src.stylesheets }/**/*.styl", ['stylus']
  gulp.watch "#{ config.client.src.images }/**", ['images']
  gulp.watch "#{ config.client.src.public }/**", ['public']

  cb()

# ------------------------------------------------------------------------------
# Default
# ------------------------------------------------------------------------------
gulp.task 'default', ->
  runSequence 'build', ['watch', 'server']
