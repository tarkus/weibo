$(document).ready ->
  socket = io.connect location.href
  socket.on 'fetching', (data) ->
    $(".sync-progress .legend").removeClass 'invisible'
    percentage = Math.round((data.current / data.total) * 100)
    $(".legend.small").text(data.current + " / " + data.total)
    $('.progress .bar').width(percentage + "%")
    if percentage is 100
      $(".sync-progress .legend").addClass 'invisible'


  $(".timeago").timeago()
  $(".weibo .thumbnail img").click ->
    $('#modal .modal-body').html('')
    clone = $(this).next().clone()
    clone.css('display', 'block').appendTo('.modal-body')
    #$("#modal").width clone[0].width + 20
    console.log $('#modal').width()
    $('#modal').css 'margin-left', "-" + $('#modal').width() / 2 + "px"
    clone.click ->
      window.open clone.attr('rel'), '_blank'
    $("#modal").modal('show')
