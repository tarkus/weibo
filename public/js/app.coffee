$(document).ready ->
  socket = io.connect location.href
  socket.on 'fetching', (data) ->
    $(".progress").show()
    percentage = Math.round((data.current / data.total) * 100)
    console.log percentage
    $('.progress .bar').width(percentage + "%")
