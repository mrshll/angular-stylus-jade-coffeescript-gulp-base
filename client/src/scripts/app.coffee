app = angular.module('portraitApp', [
  'ngLodash'
  'ui.router'
])


# @if ENV='production'
app.appRoot = ''
# @endif
#

# @if ENV='development'
app.appRoot = 'http://localhost:3001'
# @endif

app.config ($stateProvider, $urlRouterProvider, $locationProvider, $httpProvider, $sceProvider) ->

  # push-state routes
  $locationProvider.html5Mode(true)
  $urlRouterProvider.otherwise('/')

  # public routes
  $stateProvider
    .state 'public',
      abstract: true,
      template: '<ui-view/>',
      data:
        requiresLogin: false

    .state 'public.root',
      url: '/'

app.run ->
