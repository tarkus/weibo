exports.pager = (options) ->
  result =
    max: 0
    page: 0
    prev: 0
    next: 0
    pages: []
  _options =
    page: 1
    size: 30
    total: 100
    range: 3

  _options extends options
  _options.page = parseInt(_options.page)

  total_pages = result.last = Math.ceil(_options.total / _options.size)
  snap = Math.floor(_options.range / 2)


  result.max = total_pages
  result.page = parseInt(_options.page)
  result.prev = Math.max(1, _options.page - 1)
  result.next = Math.min(_options.page + 1, total_pages)

  if (_options.page - snap) <= 1
    result.pages.push i for i in [1.._options.range]
    return result
  if (_options.page + snap) >= total_pages
    page = total_pages - _options.range + 1
    while page <= total_pages
      result.pages.push page
      page++
    return result

  page = _options.page - snap
  count = 1
  while count <= _options.range
    result.pages.push page
    page++
    count++
  return result
    

