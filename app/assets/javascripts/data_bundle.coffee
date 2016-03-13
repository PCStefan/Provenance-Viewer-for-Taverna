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
      text.append('tspan').attr('x', text.attr('x')).attr('y', text.attr('y')).attr('dy', lineNumber * lineHeight + 'em' ).text(temp).filter((d) ->
        d.x < glob_width / 5
      ).attr('x', "22")
      lineNumber++

    return
  return

# distingush between single click and double click
# see http://bl.ocks.org/couchand/6394506
@clickCancel = -> 
  return

@draw = ->
  d3.json $('#data_bundle').attr('data-url'), (error, data) ->
    @tempgraph = $.extend(true, {}, data)

    if(Object.keys(tempgraph).length)
      draw_workflow()
      draw_provenance()

    return  
  return

@draw_workflow = ->
  return
  # if $('svg#graphContainer').length > 0
  #   d3.json $('#data_bundle').attr('data-url'), (error, links) ->
  #     tick = ->
  #       path.attr 'd', (d) ->
  #         dx = d.target.x - (d.source.x)
  #         dy = d.target.y - (d.source.y)
  #         dr = Math.sqrt(dx * dx + dy * dy)
  #         'M' + d.source.x + ',' + d.source.y + 'A' + dr + ',' + dr + ' 0 0,1 ' + d.target.x + ',' + d.target.y
  #       node.attr 'transform', (d) ->
  #         'translate(' + d.x + ',' + d.y + ')'
  #       return

  #     nodes = {}


  #     links.workflow.forEach (link) ->
  #       link.source = nodes[link.source] or (nodes[link.source] =
  #           name: link.source, file_content: link.file_content)
  #       link.target = nodes[link.target] or (nodes[link.target] =
  #           name: link.target, file_content: link.file_content)
  #       link.value = +link.value
  #       return

  #     width = 960
  #     height = 900

  #     force = d3.layout.force().nodes(d3.values(nodes)).links(links.workflow).size([width, height])
  #     .linkDistance(200).charge(-500).on('tick', tick).start()
  #     svgContainer = d3.select('svg#graphContainer').attr('width', width).attr('height', height)

  #     # build the arrow.
  #     svgContainer.append('svg:defs').selectAll('marker').data(['end']).enter().append('svg:marker').attr('id', String)
  #     .attr('viewBox', '0 -5 10 10').attr('refX', 15).attr('refY', -1.5).attr('markerWidth', 6)
  #     .attr('markerHeight', 6).attr('orient', 'auto').append('svg:path').attr 'd', 'M0,-5L10,0L0,5'
      
  #     # add the links and the arrows
  #     path = svgContainer.append('svg:g').selectAll('path').data(force.links()).enter().append('svg:path')
  #     .attr('class', 'link').attr('marker-end', 'url(#end)')
      
  #     # define the nodes
  #     node = svgContainer.selectAll('.node').data(force.nodes()).enter().append('g').attr('class', 'node')
  #     .attr('id', (d) -> d.name).call(force.drag)
      
  #     # add the nodes
  #     node.append('circle').attr('r', 5)
      
  #     # add the text
  #     node.append('text').attr('x', 12).attr('dy', '.35em').text (d) ->
  #       d.name
  #     node.append('text').attr('class', 'file_content').attr('visibility', 'hidden').text (d) ->
  #       return d.file_content

  #     node.on 'click', (d) ->
  #       rect = svgContainer.append('rect').transition().duration(500).attr('width', 250)
  #       .attr('height', 300).attr('x', 10).attr('y', 10).style('fill', 'white').attr('stroke', 'black')
  #       text = svgContainer.append('text').text(d.file_content)
  #       .attr('x', 50).attr('y', 150).attr('fill', 'black')
  #     return

@clone = (obj) ->
  return obj  if obj is null or typeof (obj) isnt "object"
  temp = new obj.constructor()
  for key of obj
    temp[key] = clone(obj[key])
  temp

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
        yValue = Math.min(d.y, (height - 25))
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

    # show the whole path on single click on nodes
    # the function highlight_node_links uses Breadth First Search alghorithm to find the reachable nodes
    node.on('click', click_highlight_path)
    
    # hide the links that are sourced from / targeted at current node
    node.on('dblclick', (d) ->
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