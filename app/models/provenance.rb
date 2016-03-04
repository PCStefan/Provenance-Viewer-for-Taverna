require 'sparql'  # query the graph
require 'uri'     # used to decode urls

class Provenance

	@@prefixes = "PREFIX dc:  <http://purl.org/dc/elements/1.1/>
								PREFIX prov:  <http://www.w3.org/ns/prov#>
								PREFIX cnt:  <http://www.w3.org/2011/content#>
								PREFIX foaf:  <http://xmlns.com/foaf/0.1/>
								PREFIX dcmitype:  <http://purl.org/dc/dcmitype/>
								PREFIX wfprov:  <http://purl.org/wf4ever/wfprov#>
								PREFIX dcam:  <http://purl.org/dc/dcam/>
								PREFIX xml:  <http://www.w3.org/XML/1998/namespace>
								PREFIX vs:  <http://www.w3.org/2003/06/sw-vocab-status/ns#>
								PREFIX dcterms:  <http://purl.org/dc/terms/>
								PREFIX rdfs:  <http://www.w3.org/2000/01/rdf-schema#>
								PREFIX wot:  <http://xmlns.com/wot/0.1/>
								PREFIX wfdesc:  <http://purl.org/wf4ever/wfdesc#>
								PREFIX dct:  <http://purl.org/dc/terms/>
								PREFIX tavernaprov:  <http://ns.taverna.org.uk/2012/tavernaprov/>
								PREFIX owl:  <http://www.w3.org/2002/07/owl#>
								PREFIX xsd:  <http://www.w3.org/2001/XMLSchema#>
								PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
								PREFIX skos:  <http://www.w3.org/2004/02/skos/core#>
								PREFIX scufl2:  <http://ns.taverna.org.uk/2010/scufl2#>
								"
	cattr_reader :prefixes
	attr_reader :graph

	@file = ''

	#constructor
	def initialize(filepath)
		@file = filepath

		@graph = RDF::Graph.new

		RDF::Reader.open("#{@file}") do |reader|
      reader.each_statement do |statement|
        @graph.insert(statement)
      end
    end
	end


	def getThePrimaryTopic
	  # create the query
		sparql_query = SPARQL.parse("#{Provenance.prefixes}
			SELECT ?primary_topic ?was_generated_by ?associated_agent
			WHERE { ?something  foaf:primaryTopic  ?primary_topic	.
							?something	prov:wasGeneratedBy	?was_generated_by	.
							?was_generated_by prov:wasAssociatedWith	?associated_agent . }
							")

		# return the result of the performing the query
    sparql_query.execute(graph)

	end


	# Extract from the tll the subject that has as a predicate rdf:type 
	# and is represented as an object 'wfprov:WorkflowRun'
	# Loops will create many WorflowRuns
	# to do: look for additional predicates such as wfprov:wasPartOfWorkflowRun
  def getAllWorkflowRuns
  	# create the query
		sparql_query = SPARQL.parse("#{Provenance.prefixes}
			SELECT ?workflow_run
			WHERE { ?workflow_run  rdf:type  wfprov:WorkflowRun }")

		# return the result of the performing the query
    sparql_query.execute(graph)
  end

  def getAllProcessRuns
  	sparql_query = SPARQL.parse("#{Provenance.prefixes}
			SELECT ?process_run
			WHERE { ?process_run  rdf:type  wfprov:ProcessRun }")

  	# return the processes that were used
    sparql_query.execute(graph)
	end

  def to_json
    stream = [0,1,2,3,4]

    # workflow.datalinks.each { |link| stream << write_link(link, workflow) }
    
    stream
  end

  # def write_link(link, dataflow)
  #   stream = {}
  #   if dataflow.sources.select { |s| s.name == link.source } != []
  #     stream[:source] = link.source
  #     stream[:file_content] = inputs[link.source] unless inputs[link.source].nil?
  #   else
  #     stream[:source] = processor_by_name(dataflow, link.source)
  #   end
  #   if dataflow.sinks.select { |s| s.name == link.sink } != []
  #     stream[:target] = link.sink
  #   else
  #     stream[:target] = processor_by_name(dataflow, link.sink)
  #   end
  #   stream
  # end

	# persisted is important not to get "undefined method `to_key' for" error
 	def persisted?
  	false
	end
end