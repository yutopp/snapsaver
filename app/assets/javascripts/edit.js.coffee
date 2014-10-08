# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

angular.module('app', []).controller 'ctrl', ['$scope', '$http', ($scope, $http) ->
  $scope.commit_message = ''
  $scope.logs = []

  pushLog = (log) ->
    log.time = new Date().toLocaleTimeString()
    $scope.logs.push(log)

  $scope.save = ->
    $.post '/inner_api/save_urls', {urls: $scope.urls}
      .done (data) ->
        $scope.$apply () ->
          $scope.urls = data.urls
          $scope.urlsSize = data.urls_size
          for invalid_url in  data.invalid_urls
            pushLog {isURL: false, isError: true, item: "無効なURLです: " + invalid_url}
          pushLog {isURL: false, isError: false, item: data.message}
          console.log $scope.logs
      .fail (data) ->
        console.log(data)

  $scope.shoot = (index) ->
    if index == 0
      pushLog {isURL: false, isError: false, item: "撮り始めます"}

    $.post '/inner_api/shoot', {index: index}
      .done (data) ->
        $scope.$apply () ->
          pushLog {isURL: false, isError: false, item: "(" + (index + 1) + "/" + ($scope.urlsSize + 1) + ")完了: " + data.url}

        if data.last
          $.post '/inner_api/push_repository', {commit_message: $scope.commit_message}
            .done (data) ->
              $scope.$apply () ->
                pushLog {isURL: false, isError: false, item: "(" + ($scope.urlsSize + 1) + "/" + ($scope.urlsSize + 1) + ")push完了"}
                pushLog {isURL: true, isError: false, item: data.url}
            .fail (data) ->
              $scope.$apply () ->
                pushLog {isURL: false, isError: true, item: data.responseJSON.error}
        else
          $scope.shoot index + 1
      .fail (data) ->
        $scope.$apply () ->
          pushLog {isURL: false, isError: true, item: data.responseJSON.error}
]
