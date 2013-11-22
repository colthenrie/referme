'use strict';

angular.module('refermeApp', [
  'ngCookies',
  'ngResource',
  'ngSanitize'
])
  .config(function ($routeProvider) {
    $routeProvider
      .when('/', {
        templateUrl: 'views/main.html',
        controller: 'MainCtrl'
      })
      .when('/postrefers', {
        templateUrl: 'views/postrefers.html',
        controller: 'PostrefersCtrl'
      })
      .when('/postJob', {
        templateUrl: 'views/postJob.html',
        controller: 'PostjobCtrl'
      })
      .otherwise({
        redirectTo: '/'
      });
  });
