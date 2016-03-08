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

@draw_workflow = ->
  if $('svg#graphContainer').length > 0
    d3.json $('#data_bundle').attr('data-url'), (error, links) ->
      tick = ->
        path.attr 'd', (d) ->
          dx = d.target.x - (d.source.x)
          dy = d.target.y - (d.source.y)
          dr = Math.sqrt(dx * dx + dy * dy)
          'M' + d.source.x + ',' + d.source.y + 'A' + dr + ',' + dr + ' 0 0,1 ' + d.target.x + ',' + d.target.y
        node.attr 'transform', (d) ->
          'translate(' + d.x + ',' + d.y + ')'
        return

      nodes = {}


      links.workflow.forEach (link) ->
        link.source = nodes[link.source] or (nodes[link.source] =
            name: link.source, file_content: link.file_content)
        link.target = nodes[link.target] or (nodes[link.target] =
            name: link.target, file_content: link.file_content)
        link.value = +link.value
        return

      width = 960
      height = 900

      force = d3.layout.force().nodes(d3.values(nodes)).links(links.workflow).size([width, height])
      .linkDistance(100).charge(-500).on('tick', tick).start()
      svgContainer = d3.select('svg#graphContainer').attr('width', width).attr('height', height)

      # build the arrow.
      svgContainer.append('svg:defs').selectAll('marker').data(['end']).enter().append('svg:marker').attr('id', String)
      .attr('viewBox', '0 -5 10 10').attr('refX', 15).attr('refY', -1.5).attr('markerWidth', 6)
      .attr('markerHeight', 6).attr('orient', 'auto').append('svg:path').attr 'd', 'M0,-5L10,0L0,5'
      
      # add the links and the arrows
      path = svgContainer.append('svg:g').selectAll('path').data(force.links()).enter().append('svg:path')
      .attr('class', 'link').attr('marker-end', 'url(#end)')
      
      # define the nodes
      node = svgContainer.selectAll('.node').data(force.nodes()).enter().append('g').attr('class', 'node')
      .attr('id', (d) -> d.name).call(force.drag)
      
      # add the nodes
      node.append('circle').attr('r', 5)
      
      # add the text
      node.append('text').attr('x', 12).attr('dy', '.35em').text (d) ->
        d.name
      node.append('text').attr('class', 'file_content').attr('visibility', 'hidden').text (d) ->
        return d.file_content

      node.on 'click', (d) ->
        rect = svgContainer.append('rect').transition().duration(500).attr('width', 250)
        .attr('height', 300).attr('x', 10).attr('y', 10).style('fill', 'white').attr('stroke', 'black')
        text = svgContainer.append('text').text(d.file_content)
        .attr('x', 50).attr('y', 150).attr('fill', 'black')
      return


# for every type of activity call draw_provenance
$(document).ready ->
  $('#diagramType li a').click ->
    # do something
    draw_provenance($(this).text())
    return
  return

@draw_provenance =(diagramType) ->

  # if diagramType is undefined or null, as default assign the current active
  if !diagramType?
    diagramType = $('#diagramType li.active a').text()
  
  # else clear the svg for the diagram
  else
    d3.select("svg#provContainer").selectAll("*").remove();

  draw_sankey = ->
    width = 1042
    height = 800
    lowOpacity = 0.3
    highOpacity = 0.7


    # load the svg#sankeyContainer
    # set the width and height attributes
    # append a function g that has a tranform process defined by translation
    svg = d3.select('svg#provContainer').attr('width', width).attr('height', height).append('g')

    # define the sankey object 
    # set the node width to 15
    # set the node padding to 10
    sankey = d3.sankey().nodeWidth(15).nodePadding(15).size([width, height])

    # request the sankey path of current sankey   
    path = sankey.reversibleLink()

    # load data to work with
    # function (error, links) will be defined after that $('#data_bundle').attr('data-url') will be requested and accepted  
    d3.json $('#data_bundle').attr('data-url'), (error, data) ->
      
      # set some formats 
      # round(approximate) the floating point inside the value field 
      formatNumber = d3.format(',.0f')

      format = (d) ->
        formatNumber(d)

      #generate a color for the rect based on its name
      color = d3.scale.category20()

      # set the nodes
      # set the links
      # set the layout
      sankey.nodes(data.provenance.nodes).links(data.provenance.links).layout(500)

      # select all the links from the json-data and append them to the Sankey obj in alphabetical order 
      link = svg.append('g').selectAll('.link').data(data.provenance.links).enter().append('g').attr('class', 'link').sort((a, b) ->
          b.dy - (a.dy))

      p0 = link.append("path").attr("d", path(0))
      p1 = link.append("path").attr("d", path(1))
      p2 = link.append("path").attr("d", path(2))

      link.attr('fill', (d) ->

        colorType = undefined
        switch d.source.type
          when 'Workflow Run' then colorType = '#0eff7f'
          when 'Process Run' then colorType = '#1f77b4'
          when 'Artifact' then colorType = '#ff7f0e'
          when 'Dictionary' then colorType = '#7f0eff'
          else colorType = color(stringTextForColor.replace(RegExp(' .*'), ''))        

        d.color = colorType
        ).attr('opacity', lowOpacity).on('mouseover', (d) ->
          d3.select(this).style('opacity', highOpacity)
          ).on('mouseout', (d) ->
            d3.select(this).style('opacity', lowOpacity)
            )

      # set the text for the edges
      link.append('title').text (d) ->
        startText = d.source.type + ' → ' + d.target.type + '\n' + d.source.type + ':\nURI: ' +  d.source.name
        dash = '\n-----------------------------------------------------------\n'
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
      node = svg.append('g').selectAll('.node').data(data.provenance.nodes).enter().append('g').attr('class', 'node').attr('transform', (d) ->
          yValue = Math.min d.y, (height - 25)

          yValue

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
        Math.max 15, d.dy
      ).attr('width', sankey.nodeWidth()).style('fill', (d) ->
        colorType = undefined
        switch d.type
          when 'Workflow Run' then colorType = '#0eff7f'
          when 'Process Run' then colorType = '#1f77b4'
          when 'Artifact' then colorType = '#ff7f0e'
          when 'Dictionary' then colorType = '#7f0eff'
          else colorType = color(stringTextForColor.replace(RegExp(' .*'), ''))        

        d.color = colorType
      ).style('stroke', (d) ->
        d3.rgb(d.color).darker 1
      ).append('title').text (d) ->
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

        dash = '\n---------------------------------------------------------------\n'
        returnedStr = d.type + ':' + dash + 'URI: ' + d.name 
        
        if(nodeTime == 1)
          returnedStr = returnedStr + dash + 'Start Time: ' + date_format_iso(startTime) + '\nEnd Time: ' + date_format_iso(endTime) + '\nElapsed Time: ' + hms(elapsedTime) 
      
        returnedStr

      # create function that to split the text into multiple lines
      wrap = (text) ->
        text.each ->
          text = d3.select(this)
          labels = text.text().split("\\n")
          dy = 0
          text.text(null)

          line = []
          lineNumber = 0
          lineHeight = 1.1
          for temp in labels
            lineNumber++
            text.append('tspan').attr('x', text.attr('x')).attr('y', text.attr('y')).attr('dy', lineNumber * lineHeight + dy + 'em' ).text(temp).filter((d) ->
              d.x < width / 5
            ).attr('x', "16")

          return
        return

      # set the text of the nodes
      # set their position
      # set their font
      # set the anchor of the text
      node.append('text').attr('x', (d) ->
        d.dx/2 - 9
      ).attr('y', (d) ->
        d.dy/2 
      ).attr('text-anchor', 'end')
      .text((d) ->
        
        shortenString =(temp) ->
          if temp.length > 32
            temp = temp.substring(0, 15) + '..' + temp.substring(temp.length - 15, temp.length)
          temp

        if d.hasOwnProperty("label")
          d.label 
        else
          shortenString(d.name)
      ).call(wrap).filter((d) ->
        d.x < width / 5
      ).attr('x', "16").attr('text-anchor', 'start')

      return

  if(diagramType == 'Sankey')
    draw_sankey()

