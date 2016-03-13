#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

# for every type of activity call draw_provenance
$(document).ready ->
  $('#diagramType li a').click ->
    draw_provenance($(this).text())
    return
  return

# distingush between single click and double click
# see http://bl.ocks.org/couchand/6394506

@clickCancel = -> 
  event = d3.dispatch('click', 'dblclick')

  cc = (selection) ->
    down = undefined
    tolerance = 5
    last = undefined
    wait = null
    # euclidean distance

    dist = (a, b) ->
        Math.sqrt (a[0] - (b[0])) ** 2, (a[1] - (b[1])) ** 2

    selection.on('mousedown', ->
      down = d3.mouse(document.body)
      last = +new Date
      return
    )
    selection.on('mouseup', ->
      if dist(down, d3.mouse(document.body)) > tolerance
        return
      else
        if wait
          window.clearTimeout wait
          wait = null
          event.dblclick d3.event
        else
          wait = window.setTimeout(((e) ->
            ->
              event.click e
              wait = null
              return
          )(d3.event), 300)
      return
    )
    return
  d3.rebind(cc, event, 'on')

# Here start diagrams func

@glob_width = 0
@dashLine = '\n---------------------------------------------------------------\n'
@graph = {}
@tempgraph = {}

# set the width 
@setGLWidth =(reqWidth) ->
  @glob_width = reqWidth
  return

# set a color for a node
@getColorHex =(source) ->
  color = d3.scale.category20()
  colorType = undefined
  switch source
    when 'Workflow Run' then colorType = '#0eff7f'
    when 'Process Run' then colorType = '#1f77b4'
    when 'Artifact' then colorType = '#ff7f0e'
    when 'Dictionary' then colorType = '#7f0eff'
    else colorType = color(stringTextForColor.replace(RegExp(' .*'), ''))
  colorType

# limit a string to maxChar
@shortenString =(temp, maxChar) ->
  if temp.length > maxChar
    temp = temp.substring(0, maxChar) + '..'
  temp

# limit a string to 32 chars : "{15 chars}..{15 chars}"
@shortenStringNoMiddle =(temp) ->
  if temp.length > 32
    temp = temp.substring(0, 15) + '..' + temp.substring(temp.length - 15, temp.length)
  temp

@getTimes =(d) ->
  startTime = new Date()
  endTime = new Date()
  nodeTime = 0
  if(d.hasOwnProperty("startedAtTime"))
    startTime = new Date(d.startedAtTime)
    endTime = new Date(d.endedAtTime)
    nodeTime = 1
 
  elapsedTime = endTime - startTime

  date_format_iso =(date) ->
    date.toISOString().replace( /[T]/g, ' ').slice(0, -1)

  hms =(ms) ->
    date = new Date(ms);
    str = '';
    if date.getUTCDate()-1 > 0
      str += date.getUTCDate()-1 + " days, ";
    if date.getUTCHours > 0
      str += date.getUTCHours() + " hours, ";
    if date.getUTCMinutes() > 0
      str += date.getUTCMinutes() + " minutes, ";
    if date.getUTCSeconds() > 0
      str += date.getUTCSeconds() + " seconds, ";
    str += date.getUTCMilliseconds() + " millis";
    str

  if nodeTime == 1
    'Start Time: ' + date_format_iso(startTime) + '\nEnd Time: ' + date_format_iso(endTime) + '\nElapsed Time: ' + hms(elapsedTime)
  else
    ''

# create function that to split the text into multiple lines for the svg-text
# cannot find something like this online
@wrap = (text) ->
  text.each ->
    text = d3.select(this)
    labels = text.text().split("\\n")
    text.text(null)

    line = []

    lineNumber = 1
    if(labels.length != 0)
      lineNumber = (-1) * (Math.floor(labels.length / 2) - 1)

    lineHeight = 1.1
    for temp in labels
      temp = temp.substring(temp.lastIndexOf(' '))
      text.append('tspan').attr('x', text.attr('x')).attr('y', text.attr('y')).attr('dy', lineNumber * lineHeight + 'em' ).text(temp).filter((d) ->
        d.x < glob_width / 5
      ).attr('x', "22")
      lineNumber++

    return
  return

@draw = ->
  d3.json $('#data_bundle').attr('data-url'), (error, data) ->
    @tempgraph = $.extend(true, {}, data)

    if(Object.keys(tempgraph).length)
      hasBeenDrawn = draw_workflow(hasBeenDrawn)
      draw_provenance()

    return  
  return

@clone = (obj) ->
  return obj  if obj is null or typeof (obj) isnt "object"
  temp = new obj.constructor()
  for key of obj
    temp[key] = clone(obj[key])
  temp

@draw_workflow =(draw) ->
  data = clone(@tempgraph.workflow)
  if !draw?
    width = 960
    height = 650
    opacity = 0.7

    color = d3.scale.category20()

    $('canvas#canvasWF').attr
      'width': (width + 150)
      'height': (width)

    svgContainer = d3.select('svg#graphContainer').attr('width', width+150).attr('height', width).append('g').attr('transform', (d) ->
      "translate("+ (width) + ", 0) rotate (90)"
      )

    verticalSankey = d3.vertical_sankey().nodeWidth(25).nodePadding(20).size([width-128, height])

    path = verticalSankey.link()
    
    verticalSankey.nodes(data.nodes).links(data.links).layout(32)

    link = svgContainer.append('g').selectAll('.link').data(data.links).enter().append('path').attr('class', 'link').attr('d', path).style('stroke-width', (d) ->
      Math.max 1, d.dy
    ).style('stroke', (d) ->
      d.source.color = color(d.source.name.replace(RegExp(' .*'), ''))
    ).sort((a, b) ->
      b.dx - (a.dx)
    )

    link.attr('opacity', opacity)

    link.append('title').text((d) ->
      d.source.name + '\n→\n' + d.target.name
    )

    node = svgContainer.append('g').selectAll('.node').data(data.nodes).enter().append('g').attr('class', 'node').attr('transform', (d) ->
      'translate(' + d.x + ',' + d.y + ')'
    )
    # .call(d3.behavior.drag().origin((d) ->
    #   d
    # ).on('dragstart', ->
    #   @parentNode.appendChild this
    #   return
    # ).on('drag', dragmove))

    node.append('rect').attr('width', verticalSankey.nodeWidth()).attr('height', (d) ->
      Math.abs d.dy
    ).style('fill', (d) ->
      d.color = color(d.name.replace(RegExp(' .*'), ''))
    ).style('stroke', (d) ->
      d3.rgb(d.color).darker 2
    )

    node.append('text').attr('text-anchor', 'middle').attr('y', (d) ->
      12
    ).attr('x', (d) ->
      d.dy/-2
    ).attr('dy', '.35em').attr('transform', (d) ->
      "translate("+ 0 + ", 0) rotate (270)"
    ).text((d) ->
      shortenName =(d) ->
        
        # convert the text to pixels     
        canvas = document.createElement('canvas')
        ctx = canvas.getContext("2d")
        ctx.font = "14px Source Sans Pro"
        textPX = ctx.measureText(d.name).width

        if textPX > d.dy
          d.name.substring(0, 9) + '..' + d.name.substring(d.name.length - 9, d.name.length)
        else
          d.name

      shortenName(d)

    ).filter (d) ->
      d.x < width / 2

  return true

@draw_provenance =(diagramType) ->
  # if diagramType is undefined or null, as default assign the current active
  # else clear the svg for the diagram
  if !diagramType?
    diagramType = $('#diagramType li.active a').text()  
  else
    d3.select('svg#provContainer').selectAll("*").remove()
    d3.select('svg#provContainer').remove()
    d3.select('#mapContainer').append('svg').attr('id','provContainer')
    
  @graph = clone(tempgraph)
  if(diagramType == 'Sankey')
    draw_sankey()
  
  return

@draw_sankey = ->
  width = 950
  height = 750
  lowOpacity = 0.3
  hoverOpacity = 0.7
  highOpacity = 0.9
  # load the svg#sankeyContainer
  # set the width and height attributes
  # append a function g that has a tranform process defined by translation
  svg = d3.select('svg#provContainer')

  # define the sankey object 
  # set the node width to 15
  # set the node padding to 10
  sankey = d3.sankey().nodeWidth(20).nodePadding(10)

  # request the sankey path of current sankey
  path = sankey.reversibleLink()

  # load data to work with
  # function (error, links) will be defined after that $('#data_bundle').attr('data-url') will be requested and accepted  

  # compute a better width and height for the container
  nodesCount = Object.keys(graph.provenance.nodes).length 
  linksCount = Object.keys(graph.provenance.links).length

  if nodesCount > 0 or linksCount > 0
    ratioLN = linksCount / nodesCount * 100
    width = width + Math.floor( ratioLN * 3 )
    height = height + Math.floor( ratioLN * 2 )
    setGLWidth(width)

    svg = svg.attr('width', width+150).attr('height', height+150).append('g')

    sankey = sankey.size([width, height])

    # set the nodes
    # set the links
    # set the layout
    sankey.nodes(graph.provenance.nodes).links(graph.provenance.links)
    sankey.layout(32)

    # select all the links from the json-data and append them to the Sankey obj in alphabetical order 
    link = svg.append('g').selectAll('.link').data(graph.provenance.links).enter().append('g').attr('class', 'link').attr('id', (d,i) ->
      d.id = i
      "link-" + i
    ).sort((a, b) ->
        b.dy - (a.dy))

    p0 = link.append("path").attr("d", path(0))
    p1 = link.append("path").attr("d", path(1))
    p2 = link.append("path").attr("d", path(2))

    link.attr('fill', (d) ->
      getColorHex(d.source.type)
    ).attr('opacity', lowOpacity).on('mouseover', (d) ->
      if parseFloat(d3.select(this).style('opacity')) != highOpacity
        d3.select(this).style('opacity', hoverOpacity)
      ).on('mouseout', (d) ->
        if parseFloat(d3.select(this).style('opacity')) != highOpacity
          d3.select(this).style('opacity', lowOpacity)
        )

    # set the text for the edges
    link.append('title').text (d) ->
      dash = '\n-----------------------------------------------------------\n'
      startText = d.source.type + ' → ' + d.target.type + dash + d.source.type + ':\nURI: ' +  d.source.name
      endText = d.target.type + ':\nURI: ' + d.target.name
      startText + dash + endText

    # create the function to drag the node 
    dragmove = (d) ->
      # uncomment the following to disable x movement (and comment the next line )
      #d3.select(this).attr('transform', 'translate(' + d.x + ',' + (d.y = Math.max(0, Math.min(height - (d.dy), d3.event.y))) + ')')
      d3.select(this).attr('transform', 'translate(' + (d.x = Math.max(0, Math.min(width - (d.dx), d3.event.x))) + ',' + (d.y = Math.max(0, Math.min(height - (d.dy), d3.event.y))) + ')')
      sankey.relayout()
      p0.attr("d", path(1))
      p1.attr("d", path(0))
      p2.attr("d", path(2))
      return


    # select all the nodes from the json-data and append them to the Sankey obj
    # add behavior : dragmove
    node = svg.append('g').selectAll('.node').data(graph.provenance.nodes).enter().append('g').attr('class', 'node').attr('transform', (d) ->
        yValue = Math.min(d.y, height)
        'translate(' + d.x + ',' + yValue + ')'
        ).call(d3.behavior.drag().origin((d) ->
          d
        ).on('dragstart', ->
          @parentNode.appendChild this
          return
        ).on('drag', dragmove))

    # choose the form of the node : filled rectangle
    # set the height of the rectangle to d.dy
    # set the width of the rectangle to nodeWidth?
    # set the style to be filled with default color
    node.append('rect').attr('height', (d) ->
      Math.max 10, d.dy
    ).attr('data-clicked', '0').attr('width', sankey.nodeWidth()).style('fill', (d) ->
      getColorHex(d.type)
    ).style('stroke', (d) ->
      d3.rgb(d.color).darker 1
    ).append('title').text((d) ->
      
      returnedStr = d.type + dashLine 
      returnedStr += 'URI: ' + d.name + dashLine
      returnedStr += d.label.split("\\n").join("\n")
      
      if(d.type == "Process Run")
        returnedStr += dashLine + getTimes(d)  
      else if(d.type == "Artifact" || d.type == "Dictionary" && d.content)
        returnedStr += dashLine + "Content :\n" + shortenString(d.content, 500)  
    
      returnedStr
    )

    #modify the link opacity to the given opacity
    click_highlight_path_color = (id, opacity) ->
      d3.select('#link-' + id).style('opacity', opacity)

    click_highlight_path = (node, i) ->
      # check if the user wants to drag or to click the node
      # if he wants to drag then the following will be true
      if (d3.event.defaultPrevented) 
        return
      
      remainingNodes = []
      nextNodes = []
      stroke_opacity = 0

      # if a node has been clicked and then mark it as unclick if clicked again 
      if d3.select(this).attr('data-clicked') == '1'
        d3.select(this).attr('data-clicked', '0')
        stroke_opacity = lowOpacity
      else
        d3.select(this).attr('data-clicked', '1')
        stroke_opacity = highOpacity

      # remember all visited nodes and the path 
      # traverse will be a JSON array
      traverse = [
        {
          linkType: 'sourceLinks'
          nodeType: 'target'
        }
        {
          linkType: 'targetLinks'
          nodeType: 'source'
        }
      ]

      # for each object inside traverse
      traverse.forEach (step) ->
        # for each (outgoing,incoming) link 
        node[step.linkType].forEach (link) ->
          remainingNodes.push(link[step.nodeType])
          click_highlight_path_color(link.id, stroke_opacity)
          return

        while remainingNodes.length
          nextNodes = []
          remainingNodes.forEach (node) ->
            node[step.linkType].forEach (link) ->
              nextNodes.push(link[step.nodeType])
              click_highlight_path_color(link.id, stroke_opacity)
              return
            return
          remainingNodes = nextNodes
        return
      return

    
    cc = clickCancel()

    # show the whole path on single click on nodes
    # the function highlight_node_links uses Breadth First Search alghorithm to find the reachable nodes
    # add remove the outgoing edges from current node on dblclick
    node.call(cc).on('click', click_highlight_path).on('dblclick', (d)->
      if (d3.event.defaultPrevented) 
        return
      svg.selectAll('.link').filter((l) ->
        l.source == d
      ).attr('display', ->
        if d3.select(this).attr('display') == 'none'
          'inline'
        else
          'none'
      )
      return
    )

    # set the text of the nodes
    # set their position
    # set their font
    # set the anchor of the text
    node.append('text').attr('x', (d) ->
      d.dx/2 - 12
    ).attr('y', (d) ->
      d.dy/2 - 10
    ).attr('text-anchor', 'end')
    .text((d) ->
      if d.hasOwnProperty("label")
        d.label 
      else
        shortenStringNoMiddle(d.name)
    ).call(wrap).filter((d) ->
      d.x < width / 5
    ).attr('x', "22").attr('text-anchor', 'start')

    # select all the nodes from the json-data and append them to the Sankey obj
    # add behavior : dragmove

    legendCategories = { "category":[{"type":"Workflow Run"},{"type":"Process Run"}, {"type":"Artifact"}, {"type":"Dictionary"}] }
    legend = svg.append('g').attr('class', 'legend').attr('x', 0).attr('y', 0).selectAll('.category').data(legendCategories.category).enter().append('g').attr('class', 'category')

    legendConfig =
      rectWidth: 20
      rectHeight: 12
      xOffset: 20
      yOffset: 30
      xOffsetText: 5
      yOffsetText: 10
      lineHeight: 10
      wordApart: 125

    legendConfig.xOffsetText += legendConfig.xOffset
    legendConfig.yOffsetText += legendConfig.yOffset

    legend.append('rect').attr('x', (d, i) ->
      legendConfig.xOffset + i * legendConfig.wordApart
    )
    .attr('y', legendConfig.yOffset).attr('height', legendConfig.rectHeight).attr('width', legendConfig.rectWidth).style('fill', (d) ->
      getColorHex(d.type)
    ).style('stroke', (d) ->
      d3.rgb(d.color).darker 1
    )

    legend.append('text').attr('x', (d, i) ->
      legendConfig.xOffset + i * legendConfig.wordApart + legendConfig.xOffsetText
    ).attr('y', legendConfig.yOffsetText).text((d) ->
      d.type
    )

  return



d3.select('#saveWF').on('click', ->
  html = d3.select('#wfContainer').attr('version', 1.1).attr('xmlns', 'http://www.w3.org/2000/svg').node().parentNode.innerHTML
  imgsrc = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(html)))
  img = '<img src="' + imgsrc + '">'

  console.log(html)
  canvas = document.querySelector('canvas#canvasWF')
  context = canvas.getContext("2d")
  image = new Image
  image.src = imgsrc

  image.onload = ->
    context.drawImage(image, 0, 0)
    canvasdata = canvas.toDataURL('image/png')
    pngimg = '<img src="' + canvasdata + '">'
    
    now = new Date
    differential = now.getDate() + "_" + now.getMonth() + "_" + now.getFullYear() + "_" +  now.getHours() + "_" + now.getMinutes() + "_" + now.getSeconds()

    a = document.createElement('a')
    a.download = 'workflow_' + differential + '.png'
    a.href = canvasdata
    a.click()
    return

  return
)

d3.select('#savePROV').on('click', ->
  html = d3.select('#mapContainer').attr('version', 1.1).attr('xmlns', 'http://www.w3.org/2000/svg').node().parentNode.innerHTML
  imgsrc = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(html)))
  img = '<img src="' + imgsrc + '">'

  console.log(html)
  canvas = document.querySelector('canvas#canvasPROV')
  context = canvas.getContext("2d")
  image = new Image
  image.src = imgsrc

  image.onload = ->
    context.drawImage(image, 0, 0)
    canvasdata = canvas.toDataURL('image/png')
    pngimg = '<img src="' + canvasdata + '">'
    
    now = new Date
    differential = now.getDate() + "_" + now.getMonth() + "_" + now.getFullYear() + "_" + now.getHours() + "_" + now.getMinutes() + "_" + now.getSeconds()


    a = document.createElement('a')
    a.download = 'provenance_' + differential + '.png'
    a.href = canvasdata
    a.click()
    return

  return
)