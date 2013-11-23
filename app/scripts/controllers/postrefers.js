'use strict';

angular.module('refermeApp')
  .controller('PostrefersCtrl', function($scope) {
  $scope.list1 = [
    {name: 'AngularJS', reject: true},
    {name: 'Is'},
    {name: 'teh'},
    {name: '@wesome'}
  ];
  
  $scope.list2 = [];
});