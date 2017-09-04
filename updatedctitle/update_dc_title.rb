require_relative 'propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class UpdateDcTitle
#  @namespaces = { 'dc'     => 'http://purl.org/dc/elements/1.1/',
#                  'oaidc'  => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
#                  'vra'     => 'http://dlib.york.ac.uk/vra4york'
#  }
#  @namespaces = { 'vra'   => 'http://dlib.york.ac.uk/vra4york'}

  def initialize()
    @current_heading = 'Linstrum, Derek'
    @collection       = 'york:815234'

    puts 'loading system properties ...'
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']
    @solrquery= @props['solrquery']

    @conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    @conn.basic_auth(@admin, @password)

    puts 'loading pid list ...'
    @pids = []
    addpid(@collection)
    checkdccontributor()
  end

  def addpid(collectionid)
    query = (@solrquery.gsub('__PID__', collectionid)).gsub('__EQUAL__', '=')
    #puts query
    #puts '--------------------------------'
    solr     = @conn.get query
    solr_doc = Nokogiri::XML(solr.body.to_s)
    #puts solr_doc.to_xml

    objects  = solr_doc.xpath("/response/result/doc")
    for object in objects
      pid = object.xpath("str[@name='PID']")
      iscollection=object.xpath("arr[@name='rdf.rel.isCollection']/str")
      if "true"== iscollection.text
        addpid(pid.text)
      else
        @pids.push pid.text
      end
    end
  end

  def checkdccontributor()
    puts 'total: ' + @pids.length.to_s
    puts '-------------------------------'

    notupdated = 0
    updated    = 0
    for pid in @pids
      originalpid = pid.dup
      unique_labels = Set.new()

      puts (updated+notupdated).to_s + '/' + @pids.length.to_s + ' checking dc/vra for ' + pid + ' ...'
	    needtochange = true

  	  solr          = @conn.get '/solr/select/?q=PID:'+(pid.sub! ':', '?')
	    solr_doc      = Nokogiri::XML(solr.body.to_s)
	    dccontributor = solr_doc.xpath("/response/result/doc[str[@name='PID']='"+originalpid+"']/arr[@name='dc.contributor']")
      if !dccontributor.nil? and dccontributor==@current_heading
        needtochange = false
      end
	  
      if needtochange == true
        updated+=1
        update_dc_contributor(originalpid)
        update_vra(originalpid)
      else
        notupdated+=1
	      puts '  no need to update'
	    end
    end

    puts '-------------------------------'
    puts 'Total updated: ' + updated.to_s
    puts 'Total not updated: ' + notupdated.to_s
  end

  def update_dc_contributor(pid)
    changed = false
    puts '  updating DC'
    dc = @conn.get '/fedora/objects/'+pid+'/datastreams/DC/content'
    dc_doc = Nokogiri::XML(dc.body.to_s)
    dc_contributor_element = dc_doc.at_xpath("/oai_dc:dc/dc:contributor")
    if dc_contributor_element.nil? or dc_contributor_element.text==''
      puts 'Adding a new dc:contributor.'
      dc_contributor = Nokogiri::XML::Node.new "dc:contributor", dc_doc
      dc_contributor.content = @current_heading
      changed = true
    elsif dc_contributor_element.text.start_with? @current_heading
      dc_contributor_element.content = @current_heading
      changed = true
    else
      puts 'Bypass ' + dc_contributor_element.text
      changed = false
    end

    if changed
      resp = @conn.put '/fedora/objects/'+pid+'/datastreams/DC', dc_doc.to_s do |req|
        req.headers['Content-Type'] = 'text/xml'
      end
      puts '    updated DC for ' + pid
    end
  end

  def update_vra(pid)
    changed = false
    puts '  updating VRA'

    vra = @conn.get '/fedora/objects/'+pid+'/datastreams/VRA/content'

    vra_doc = Nokogiri::XML(vra.body.to_s)

    vra_agentset_element     = vra_doc.xpath("/vra:vra/vra:image/vra:agentSet", 'vra'   => 'http://dlib.york.ac.uk/vra4york')

    vra_photographer_element = vra_doc.xpath("/vra:vra/vra:image/vra:agentSet/vra:agent[vra:role='photographer']/vra:name[@type='personal']", 'vra'   => 'http://dlib.york.ac.uk/vra4york')
    if vra_photographer_element.nil? or vra_photographer_element.text==''
      puts 'Adding a new vra:agent.'
      vra_agent = Nokogiri::XML::Node.new "vra:agent", vra_doc
      vra_agentset_element << vra_agent

      vra_role  = Nokogiri::XML::Node.new "vra:role", vra_doc
      vra_role['href'] = 'http://www.loc.gov/loc.terms/relators/PHT'
      vra_role['vocab'] = 'http://www.loc.gov/loc.terms/relators/'
      vra_role.content   =  'photographer'
      vra_agent << vra_role

      vra_name  = Nokogiri::XML::Node.new "vra:name", vra_doc
      vra_name['type'] = 'personal'
      vra_name['vocab'] = ''
      vra_name.content   = @current_heading
      vra_agent << vra_name

      changed = true
    elsif vra_photographer_element.text.start_with? @current_heading
      vra_photographer_element.first.content = @current_heading
      changed = true
    else
      puts 'Bypass ' + vra_photographer_element.text
      changed = false
    end

    if changed
      resp = @conn.put '/fedora/objects/'+pid+'/datastreams/VRA', vra_doc.to_s do |req|
        req.headers['Content-Type'] = 'text/xml'
      end
      puts '    updated VRA for ' + pid
    end
  end
end

udt = UpdateDcTitle.new()




