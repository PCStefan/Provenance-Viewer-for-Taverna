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

require 'uri'     # used to decode urls
require 'sparql'  # query the graph

class DataBundleDecorator < Draper::Decorator
  delegate_all

  FILE_TYPES = {
      inputs: '/inputs/',
      intermediates: '/intermediates/',
      outputs: '/outputs/'
  }

  FILE_TYPES.each do |type_key, type_name|
    define_method :"#{type_key}" do
      files = manifest['aggregates'].select { |files| files['folder'].start_with?(type_name) }
      result = {}
      files.each do |file|
        key = file['file'].split('/').last.split('.').first
        result[key] = file_content(file['file'])
      end
      return result
    end
  end

  def file_content(file)
    File.new("#{object.file_path}#{file}", 'r').read
  end

  def manifest
    if @manifest.nil?
      file = File.new("#{object.file_path}.ro/manifest.json", 'r')
      @manifest = JSON.parse(file.read)
    end

    @manifest
  end

  def workflow
    if @workflow.nil?

      manifest = Nokogiri::XML(File.open("#{object.file_path}#{DataBundle::EXTRACTED_WORKFLOW_PATH}/META-INF/manifest.xml"))
      stefan = File.open("#{object.file_path}#{DataBundle::EXTRACTED_WORKFLOW_PATH}/META-INF/manifest.xml")
      t2flow_name = manifest.xpath('//manifest:file-entry[@manifest:media-type="application/vnd.taverna.t2flow+xml"][@manifest:size]').first['manifest:full-path']
      file = File.open("#{object.file_path}#{DataBundle::EXTRACTED_WORKFLOW_PATH}/#{t2flow_name}")
      @workflow = T2Flow::Parser.new.parse(file)
    end

    @workflow
  end

  def to_json
    stream = []
    workflow.datalinks.each { |link| stream << write_link(link, workflow) }
    stream
  end

  def write_link(link, dataflow)
    stream = {}
    if dataflow.sources.select { |s| s.name == link.source } != []
      stream[:source] = link.source
      stream[:file_content] = inputs[link.source] unless inputs[link.source].nil?
    else
      stream[:source] = processor_by_name(dataflow, link.source)
    end
    if dataflow.sinks.select { |s| s.name == link.sink } != []
      stream[:target] = link.sink
    else
      stream[:target] = processor_by_name(dataflow, link.sink)
    end
    stream
  end

  def processor_by_name(dataflow, name)
    dataflow.processors.select { |p| p.name == name.split(':').first }.first.name
  end

  # test function for jquery tabs
  def test1 
    @test = "test string"
  end

  # find the provenance file
  # how to extract info from file see http://ruby-rdf.github.io/ , section Querying RDF data using basic graph patterns
  def provenanceMain
    
    if @provenance.nil?

      # create a graph
      graph = RDF::Graph.new
      p "==========================>>>>  Create empty graph"
      p "Check if the graph is empty. (correct : true)"
      p "=> #{graph.empty?}"
      p "See the length: (correct : 0)"
      p "=> #{graph.count}"


      # Add the prov data in turtle format
      RDF::Reader.open("https://raw.githubusercontent.com/Data2Semantics/provoviz/master/src/app/static/prov-o.ttl") do |reader|
        reader.each_statement do |statement|
          graph.insert(statement)
        end
      end 

      p "==========================>>>>  Loading PROV data in Turtle format"
      p "Check if the graph is empty. (correct : false)"
      p "=> #{graph.empty?}"
      p "See the length: (correct : >0)"
      p "=> #{graph.count}"


      # Generating graph
      # get the data (as triplets{sub,pred, obj}) from the file into the graph 
      # RDF::Reader.open("#{object.file_path}workflowrun.prov.ttl") do |reader|
      RDF::Reader.open("https://raw.githubusercontent.com/Data2Semantics/provoviz/master/examples/workflowrun-taverna-provo.n3") do |reader|
        reader.each_statement do |statement|
          graph.insert(statement)
        end
      end 

      p "==========================>>>>  Generating graphs"
      p "Parse source file adding the resulting triples to the Graph."
      p "Check if any triplet has been inserted into the graph. (correct : false)"
      p "=> #{graph.empty?}"
      p "See the length: (correct : >0)"
      p "=> #{graph.count}"



      # Generating provenance graphs...
      buildFullGraph(graph)

      p "==========================>>>>  Generating provenance graphs..."



      @provenance = graph
    end # if provenance

    #return 
    @provenance 
  end # def provenance



  def buildFullGraph(graph)
    p "/buildFullGraph------------->>>>  Building full provenance graph..."


    # Create a new graph
    digraph = GraphViz.new( :G, :type => :digraph )


    # activity -> resource 
    p "Running activity_to_resource"
    
    activity_to_resource_SQL = SPARQL.parse("
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        PREFIX owl: <http://www.w3.org/2002/07/owl#>

        SELECT DISTINCT ?activity ?activity_type ?activity_label ?entity ?entity_type ?entity_label 
        WHERE {
          { ?entity prov:wasGeneratedBy ?activity . }
          UNION
          { ?activity prov:generated ?entity . }
          UNION
          { 
            ?entity prov:qualifiedGeneration ?qg .
            ?qg   prov:activity ?activity .
          }
          OPTIONAL { ?activity rdf:type ?activity_type .
                     ?activity_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                     FILTER(!isBlank(?activity_type)) }
          OPTIONAL { ?activity rdfs:label ?activity_label .}
          OPTIONAL { ?entity rdfs:label ?entity_label . }
          OPTIONAL { ?entity rdf:type ?entity_type .
                     ?entity_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                     FILTER(!isBlank(?entity_type)) }
        }")
    digraph = buildGraph(digraph, activity_to_resource_SQL, graph, "activity", "entity")

    # response -> activity 
    p "Running resource_to_activity"

    resource_to_activity_SQL = SPARQL.parse("
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        PREFIX owl: <http://www.w3.org/2002/07/owl#>

        SELECT DISTINCT ?entity ?entity_type ?entity_label ?activity ?activity_type ?activity_label 
        WHERE {
            { ?activity prov:used ?entity . }
            UNION
            { ?entity prov:wasUsedBy ?activity . }
            UNION
            { 
              ?activity prov:qualifiedUsage ?qu .
              ?qu     prov:entity ?entity .
            }
            OPTIONAL { ?activity rdf:type ?activity_type .
                       ?activity_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                       FILTER(!isBlank(?activity_type)) }
            OPTIONAL { ?activity rdfs:label ?activity_label . }
            OPTIONAL { ?entity rdf:type ?entity_type .
                       ?entity_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                       FILTER(!isBlank(?entity_type)) }
            OPTIONAL { ?entity rdfs:label ?entity_label . }   
        }")
    digraph = buildGraph(digraph, resource_to_activity_SQL, graph, "entity", "activity")

    # derived_from
    p "Running derived_from"

    derived_from_SQL = SPARQL.parse("
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        PREFIX owl: <http://www.w3.org/2002/07/owl#>

        SELECT DISTINCT ?entity1 ?entity1_type ?entity1_label ?entity2 ?entity2_type ?entity2_label 
        WHERE {
            ?entity2 prov:wasDerivedFrom ?entity1 .
            OPTIONAL { ?entity1 rdf:type ?entity1_type .
                       ?entity1_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                       FILTER(!isBlank(?entity1_type)) }
            OPTIONAL { ?entity1 rdfs:label ?entity1_label .}
            OPTIONAL { ?entity2 rdfs:label ?entity2_label . }
            OPTIONAL { ?entity2 rdf:type ?entity2_type .
                       ?entity2_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                       FILTER(!isBlank(?entity2_type))}
        }")
    digraph = buildGraph(digraph, derived_from_SQL, graph, "entity1", "entity2")

    # informed_by
    p "Running informed_by"

    informed_by_SQL = SPARQL.parse("
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        PREFIX owl: <http://www.w3.org/2002/07/owl#>

        SELECT DISTINCT ?activity1 ?activity1_type ?activity1_label ?activity2 ?activity2_type ?activity2_label WHERE {
            ?activity2 prov:wasInformedBy ?activity1 .
              OPTIONAL { ?activity1 rdf:type ?activity1_type .
                     ?activity1_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                     FILTER(!isBlank(?activity1_type)) }
              OPTIONAL { ?activity1 rdfs:label ?activity1_label .}
              OPTIONAL { ?activity2 rdfs:label ?activity2_label . }
              OPTIONAL { ?activity2 rdf:type ?activity2_type .
                     ?activity2_type rdfs:isDefinedBy <http://www.w3.org/ns/prov-o#> .
                     FILTER(!isBlank(?activity2_type))}
        }")
    digraph = buildGraph(digraph, informed_by_SQL, graph, "activity1", "activity2")

    # skip line 221

    # continue line 229
    digraph.edges 


  end

  # source and target refer to types of subjects inside de RDF-turtle file
  def buildGraph(digraph, sqlQuery, graph, source, target)

    p "Building edges from #{source} to #{target}"
    p "Directly querying"

    sqlQuery.execute(graph) do |result|

      if result[source].blank? or result[target].blank?
        p "This result is not usable as there is no binding to source and/or target"
      end

      source_uri = result[source].to_s.encode('utf-8')
      target_uri = result[target].to_s.encode('utf-8')
      regex_quote = "'"           # the quote
      regex_type = "/((\d)+)\z/"  # the digits at the end of var

      begin
        source_binding = shorten(result[source+'_label'].to_s)
      ensure
        source_binding = uri_to_label(result[source].to_s).gsub(regex_quote,'')
      end

      begin
        target_binding = shorten(result[target+'_label'].to_s)
      ensure
        target_binding = uri_to_label(result[target].to_s).gsub(regex_quote,'')
      end

      begin
        source_type = result[source+'_type'].to_s
      ensure
        source_type = result[source].to_s.sub(regex_type,'')
      end

      begin
        target_type = result[target+'_type'].to_s
      ensure
        target_type = result[target].to_s.sub(regex_type,'')
      end


      begin 
        regex_type_final = "/.*?[\\#]/"
        source_type = source_type.sub(regex_type_final, '')
        target_type = target_type.sub(regex_type_final, '')
      end

      digraph.add_nodes(source_uri , :label => source_binding, :comment => source_type, :URL => source_uri)
      digraph.add_nodes(target_uri , :label => target_binding, :comment => target_type, :URL => target_uri)
      digraph.add_edges(source_uri, target_uri, :weight => 10 )
      
    end

    p "Query-based graph building complete #{source} to #{target}."

    digraph
  end

  # Make any string longer than 32 chars to [{first 15 chars} + .. + {last 15 chars}]
  def shorten(text)
    if text.length > 32
      text = text[0..15] + ".." + text[(text.length - 15), text.length]
    end

    text
  end

  # extract the path or uri by removing the htpp://website_domain/ 
  def uri_to_label(uri)
    if uri =~ /[\\#]/
      base, hash_sign, local_name = uri.rpartition("\#")
      base_uri = local_name.to_s.encode('utf-8')
    else
      regex = /http:\/\/(.*?)\//
      base_uri = uri.sub(regex, '').to_s.encode('utf-8')
    end

    shorten(unquote_plus_stripped(base_uri))
  end

  # remove any + and any html percent html symbols and replace them with space
  def unquote_plus_stripped(uri)
    base_uri = URI.decode_www_form_component(uri)
    
    # replace all occurences of _ with space
    regex = "_"
    base_uri = base_uri.gsub(regex, ' ').to_s.encode('utf-8')

    # replace any leading dash and space
    regex_space = /\A(-)*( )*/
    base_uri = base_uri.sub(regex_space, '').to_s.encode('utf-8')
    
    base_uri
  end

end
