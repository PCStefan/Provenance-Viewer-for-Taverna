require 'sparql'  # query the graph
require 'uri'     # used to decode urls

class Provenance

	# TODO: try to read the prefixes from the file
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

	#Extract all the workflows and their parent workflow
  def getAllWorkflowRuns
  	# create the query
		sparql_query = SPARQL.parse("#{Provenance.prefixes}
			SELECT *
      WHERE
        { 
          ?workflowRun  rdf:type  wfprov:WorkflowRun
          OPTIONAL
          { ?workflowRun  wfprov:wasPartOfWorkflowRun  ?wasPartOfWorkflowRun }
        }")

		#return the result of the performing the query
    sparql_query.execute(@graph)
  end
 
  # Get all the ProcessRuns and their outlinks
  def getAllProcessRuns
  	sparql_query = SPARQL.parse("#{Provenance.prefixes}		
      SELECT  *
      WHERE
      { 
        ?processURI  rdf:type         wfprov:ProcessRun ;
                     prov:startedAtTime  ?startedAtTime ;
                     prov:endedAtTime    ?endedAtTime
        OPTIONAL
          { ?processURI  wfprov:wasPartOfWorkflowRun  ?wasPartOfWorkflow }
        OPTIONAL
        { 
          ?processURI  wfprov:usedInput  ?usedArtifactInput
          FILTER NOT EXISTS { ?usedArtifactInput  rdf:type  prov:Dictionary  }
        }
        OPTIONAL
        { 
          ?processURI  wfprov:usedInput  ?usedDictionaryInput .
          ?usedDictionaryInput  rdf:type  prov:Dictionary
        }
        OPTIONAL
          { ?processURI  wfprov:wasEnactedBy  ?engineUsed }
      }")

  	# return the processes that were used
    sparql_query.execute(@graph)
	end

	#Extract all the workflows and their parent workflow
  def getAllArtifacts
  	# create the query
		sparql_query = SPARQL.parse("#{Provenance.prefixes}
			SELECT *
      WHERE
      {
        { 
          ?artifactURI  rdf:type  wfprov:Artifact
          OPTIONAL
          { 
            ?artifactURI  wfprov:wasOutputFrom  ?outputFromWorkflowRun .
            ?outputFromWorkflowRun  rdf:type  wfprov:WorkflowRun
          }
          OPTIONAL
          { 
            ?artifactURI  wfprov:wasOutputFrom  ?outputFromProcessRun .
            ?outputFromProcessRun  rdf:type  wfprov:ProcessRun  ;
                                   prov:startedAtTime  ?startedAtTime ;
                                   prov:endedAtTime    ?endedAtTime
          }
          FILTER NOT EXISTS { ?artifactURI  rdf:type  prov:Dictionary }
        }
        UNION
        { 
          ?dictionary  rdf:type  prov:Dictionary
          OPTIONAL
            { ?dictionary  prov:hadMember  ?hadMember }
          OPTIONAL
          { 
            ?dictionary  wfprov:wasOutputFrom  ?outputFromWorkflowRun .
            ?outputFromWorkflowRun  rdf:type  wfprov:WorkflowRun
          }
          OPTIONAL
          { 
            ?dictionary  wfprov:wasOutputFrom  ?outputFromProcessRun .
            ?outputFromProcessRun  rdf:type  wfprov:ProcessRun  ;
                                   prov:startedAtTime  ?startedAtTime ;
                                   prov:endedAtTime    ?endedAtTime
          }
        }
      }")

		# return the result of the performing the query
    sparql_query.execute(@graph)
  end

  def to_json

  	nodes = []
  	links = []

  	# get all the workflows
  	getAllWorkflowRuns.each do |result|

  		# get the name
  		workflowRunURI = result["workflowRun"].to_s

  		# a temp node for current (Decide whether to be added or not)
  		workflowRun = {:name => workflowRunURI, :type => "Workflow Run"}

  		# see if exists
  		indexSource = nodes.find_index(workflowRun)

  		# check
  		if indexSource.blank?
  			indexSource = nodes.count
  			nodes << workflowRun
  		end

  		# check if has property wasPartOfWorkflowRun 
  		if result["wasPartOfWorkflowRun"].present?

  			secondWorkflowRun = {:name => result["wasPartOfWorkflowRun"].to_s, :type => "Workflow Run"}

  			indexTarget = nodes.find_index(secondWorkflowRun)

  			if indexTarget.blank?
  				indexTarget = nodes.count
  				nodes << secondWorkflowRun
  			end

  			# add the link
  			linkWfToWf = {:source => indexSource, :target => indexTarget, :value => "50"}
  			if links.find_index(linkWfToWf).blank?
  				links << linkWfToWf
  			end
  		end
  	end

  	# get all the processes
  	# get all the workflows
  	getAllProcessRuns.each do |result|

  		# get the name
  		processRunURI = result["processURI"].to_s

  		# a temp node for current (Decide whether to be added or not)
  		processRun = {:name => processRunURI, :type => "Process Run", :startedAtTime => result["startedAtTime"].to_s, :endedAtTime =>result["endedAtTime"].to_s}

  		# see if exists
  		indexSource = nodes.find_index(processRun)

  		# check
  		if indexSource.blank?
  			indexSource = nodes.count
  			nodes << processRun
  		end

  		# check if has property wasPartOfWorkflow
  		if result["wasPartOfWorkflow"].present?
  			workflowRun = {:name => result["wasPartOfWorkflow"].to_s, :type => "Workflow Run"}

  			indexTarget = nodes.find_index(workflowRun)

  			if indexTarget.blank?
  				indexTarget = nodes.count
  				nodes << workflowRun
  			end

  			# add the link
  			linkProcessToWf = {:source => indexSource, :target => indexTarget, :value => "50"}
  			if links.find_index(linkProcessToWf).blank?
  				links << linkProcessToWf
  			end
  		end
      
  		# check if has property usedInput 
  		if result["usedArtifactInput"].present?
  			artifact = {:name => result["usedArtifactInput"].to_s, :type => "Artifact" }

  			indexTarget = nodes.find_index(artifact)

  			if indexTarget.blank?
  				indexTarget = nodes.count
  				nodes << artifact
  			end

  			# add the link
  			linkProcessToArtifact = {:source => indexSource, :target => indexTarget, :value => "50"}
  			if links.find_index(linkProcessToArtifact).blank?
  				links << linkProcessToArtifact
  			end
  		end

      # check if has property usedInput 
      if result["usedDictionaryInput"].present?
        dictionary = {:name => result["usedDictionaryInput"].to_s, :type => "Dictionary" }

        indexTarget = nodes.find_index(artifact)

        if indexTarget.blank?
          indexTarget = nodes.count
          nodes << dictionary
        end

        # add the link
        linkProcessToArtifact = {:source => indexSource, :target => indexTarget, :value => "50"}
        if links.find_index(linkProcessToArtifact).blank?
          links << linkProcessToArtifact
        end
      end



  		# check if has property engineUsed which represents the wfprov:wasEnactedBy 
  		if result["engineUsed"].present?
  			engine = {:name => result["engineUsed"].to_s, :type => "Engine"}

  			indexTarget = nodes.find_index(engine)

  			if indexTarget.blank?
  				indexTarget = nodes.count
  				nodes << engine
  			end

        # add the link
  			linkProcessToEngine = {:source => indexSource, :target => indexTarget, :value => "50"}
  			if links.find_index(linkProcessToEngine).blank?
  				links << linkProcessToEngine
  			end
  		end

  	end


  	# get all the nodes and links related to the artifact
  	getAllArtifacts.each do |result|
  		
      if result["artifactURI"].present?
    		# get the name
    		artifactURI = result["artifactURI"].to_s

    		# the node that need to be added to the nodes
    		artifact = {:name => artifactURI, :type => "Artifact"}
      else
        # get the name
        artifactURI = result["dictionary"].to_s

        # the node that need to be added to the nodes
        artifact = {:name => artifactURI, :type => "Dictionary"}
      end

  		# get the index of the artifact if present otherwise nil
  		indexSource = nodes.find_index(artifact)

  		# check if is already in the list if not add to nodes
  		if indexSource.blank?
  			indexSource = nodes.count
  			nodes << artifact
  		end

  		# check if it has the property wasOutputFrom a process Run and add a link entity-process
  		if result["outputFromProcessRun"].present?
				processRun = {:name => result["outputFromProcessRun"].to_s, :type => "Process Run", :startedAtTime => result["startedAtTime"].to_s, :endedAtTime =>result["endedAtTime"].to_s}
		
				indexTarget = nodes.find_index(processRun)

				if indexTarget.blank?
					indexTarget = nodes.count
  				nodes << processRun
  			end

  			# add the link
  			linkArtifactToProcess = {:source => indexSource, :target => indexTarget, :value => "50"}
  			if links.find_index(linkArtifactToProcess).blank?
  				links << linkArtifactToProcess
  			end
  		end

      if result["outputFromWorkflowRun"].present?
        workflowRun = {:name => result["outputFromWorkflowRun"].to_s, :type => "Workflow Run"}
    
        indexTarget = nodes.find_index(workflowRun)

        if indexTarget.blank?
          indexTarget = nodes.count
          nodes << workflowRun
        end

        # add the link
        linkArtifactToWorkflow = {:source => indexSource, :target => indexTarget, :value => "50"}
        if links.find_index(linkArtifactToWorkflow).blank?
          links << linkArtifactToWorkflow
        end
      end

      if result["hadMember"].present?
        artifact = {:name => result["hadMember"].to_s, :type => "Artifact"}
    
        indexTarget = nodes.find_index(artifact)

        if indexTarget.blank?
          indexTarget = nodes.count
          nodes << artifact
        end

        # add the link
        linkDictToArtifact = {:source => indexSource, :target => indexTarget, :value => "50"}
        if links.find_index(linkDictToArtifact).blank?
          links << linkDictToArtifact
        end
      end
		end

		# make a hash to return
		stream = {:nodes => nodes, :links => links }

		# return stream
    stream
  end

	# persisted is important not to get "undefined method `to_key' for" error
 	def persisted?
  	false
	end
end