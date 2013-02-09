# graph 'fps', 1/dt, type:'positive'
# markGraph 'fps'
# drawGraphs x, y
# holdAllGraphs()

class Graph
  num_points = width = 200
  height = 30
  center = height / 2
  constructor: (@name, @opts) ->
    @frontBuf = document.createElement 'canvas' # displayed
    @backBuf = document.createElement 'canvas' # used to construct frame n+1
    @data = []
    @marks = []
    for b in [@frontBuf, @backBuf]
      b.width = num_points
      b.height = height
    ctx = @frontBuf.getContext '2d'
    ctx.fillStyle = 'rgba(0,0,0,0.2)'
    ctx.fillRect 0,0, @frontBuf.width, @frontBuf.height
  add: (v) ->
    @data.unshift v
    @data.length = Math.min @data.length, num_points
    ctx = @backBuf.getContext '2d'
    # draw front buf to back buf, offset left by 1px
    ctx.clearRect 0, 0, width, height
    ctx.drawImage @frontBuf, -1, 0
    ctx.fillStyle = 'rgba(0,0,0,0.2)'
    ctx.fillRect width-1, 0, 1, height
    if @opts.type is 'center'
      if v > 0
        ctx.fillStyle = 'hsla(129,80%,50%,0.5)'
        h = Math.min(v, @opts.scale)/@opts.scale*height/2
        ctx.fillRect width-1, center-h, 1, h
        v -= @opts.scale
        while v > 0
          h = Math.min(v, @opts.scale*2)/@opts.scale*height/2
          ctx.fillRect width-1, height-h, 1, h
          v -= @opts.scale*2
      else
        v = -v
        ctx.fillStyle = 'hsla(346,80%,50%,0.5)'
        h = Math.min(v, @opts.scale)/@opts.scale*height/2
        ctx.fillRect width-1, center, 1, h
        v -= @opts.scale
        while v > 0
          h = Math.min(v, @opts.scale*2)/@opts.scale*height/2
          ctx.fillRect width-1, 0, 1, h
          v -= @opts.scale*2
    else
      ctx.fillStyle = 'hsla(129,80%,50%,0.5)'
      while v > 0
        h = Math.min(v, @opts.scale)/@opts.scale*height
        ctx.fillRect width-1, height-h, 1, h
        v -= @opts.scale
    tmp = @frontBuf
    @frontBuf = @backBuf
    @backBuf = tmp
    return
  draw: (ctx, x, y) ->
    ctx.drawImage @frontBuf, x, y
    ctx.font = '10px helvetica'
    ctx.textBaseline = 'middle'
    ctx.fillStyle = 'black'
    if @opts.type is 'positive'
      ctx.fillText @opts.scale, width+2, 0
      ctx.fillText '0', width+2, height
    else
      ctx.fillText @opts.scale, width+2, 0
      ctx.fillText -@opts.scale, width+2, height
    ctx.fillText @data[0].toFixed(1), width+2, center
  hold: ->
    g = new Graph @name, @opts
    for own k,v of @ when k not in ['frontBuf', 'backBuf', 'name', 'opts']
      g[k] = JSON.parse JSON.stringify v
    cx = g.frontBuf.getContext '2d'
    cx.clearRect 0, 0, width, height
    cx.drawImage @frontBuf, 0, 0
    g

graphs = {}
heldGraphs = {}

graph = (name, val, opts) ->
  g = (graphs[name] ?= new Graph name, opts)
  g.add val if val
  g

drawGraphs = (x, y, gs=graphs) ->
  ctx.save()
  ctx.translate x, y
  for n,g of gs
    g.draw ctx, 0, 0
    ctx.translate 0, 50
  ctx.restore()

holdAllGraphs = ->
  for n,g of graphs
    heldGraphs[n] = g.hold()
  return

drawHeldGraphs = (x, y) ->
  drawGraphs x, y, heldGraphs
