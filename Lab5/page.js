angular.module('profileModule', [])
.controller('ProfileCtrl', [
  '$scope','$http',
  function($scope,$http){
    $scope.profile = {
      "name": "",
      "location":"",
      "alert_number":"",
      "threshold":"80"
    };
    $scope.eci = "ckkt27mlt00g28duthea10l2b";
    $scope.baseURL = "http://localhost:3000/";

    var profileQURL = $scope.baseURL+'sky/cloud/'+$scope.eci+'/sensor_profile/profile_info';
    $scope.getProfile = function(number) {
      return $http.get(profileQURL).success(function(data){
        angular.copy(data, $scope.profile);
      });
    };

    $scope.getProfile();

    var profileEURL = $scope.baseURL+'sky/event/'+$scope.eci+'/sensor_profile/sensor/profile_updated';
    $scope.updateProfile = function() {
      var URL = profileEURL + "?name=" + $scope.profile["name"] + "&location=" + $scope.profile["location"]
      + "&alert_number=" + $scope.profile["alert_number"] + "&threshold=" + $scope.profile["threshold"];
      return $http.post(URL).success(function(data){
        $scope.getProfile();
      });
    };
  }
]);