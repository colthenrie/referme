'use strict';

describe('Controller: PostjobCtrl', function () {

  // load the controller's module
  beforeEach(module('refermeApp'));

  var PostjobCtrl,
    scope;

  // Initialize the controller and a mock scope
  beforeEach(inject(function ($controller, $rootScope) {
    scope = $rootScope.$new();
    PostjobCtrl = $controller('PostjobCtrl', {
      $scope: scope
    });
  }));

  it('should attach a list of awesomeThings to the scope', function () {
    expect(scope.awesomeThings.length).toBe(3);
  });
});
