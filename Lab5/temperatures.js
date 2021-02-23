angular.module('tempModule', [])
.controller('TempCtrl', [
  '$scope','$http',
  function($scope,$http){
    $scope.currentTemp = "";
    $scope.temps = [];
    $scope.violations = [];
    $scope.eci = "ckkt27mlt00g28duthea10l2b";
    $scope.baseURL = "http://localhost:3000/";

    var tempsQURL = $scope.baseURL+'sky/cloud/'+$scope.eci+'/temperature_store/temperatures';
    $scope.getTemps = function() {
      return $http.get(tempsQURL).success(function(data){
        $scope.temps = []
        Object.keys(data).forEach(function(key)
        {
            $scope.temps.push({"time":key, "temp":data[key]});
        });
        $scope.temps.sort(function(a,b){return (a.time < b.time) ? 1 : (a.time > b.time) ? -1 : 0;})
        $scope.currentTemp = $scope.temps[0]["temp"];
      });
    };

    var violationsQURL = $scope.baseURL+'sky/cloud/'+$scope.eci+'/temperature_store/threshold_violations';
    $scope.getViolations = function() {
      return $http.get(violationsQURL).success(function(data){
        $scope.violations = []
        Object.keys(data).forEach(function(key)
        {
            $scope.violations.push({"time":key, "temp":data[key]});
        });
        $scope.violations.sort(function(a,b){return (a.time < b.time) ? 1 : (a.time > b.time) ? -1 : 0;})
        $scope.currentTemp = $scope.violations[0]["temp"];
      });
    };

    $scope.getTemps();
    $scope.getViolations();

    }
]);