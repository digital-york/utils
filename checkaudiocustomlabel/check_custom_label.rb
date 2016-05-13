require_relative 'propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class CheckCustomLabel
  def initialize()
    @namespaces = { 'rdfs'   => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
                    'relint' => 'http://dlib.york.ac.uk/rel-int#',
                    'dc'     => 'http://purl.org/dc/elements/1.1/',
                    'oaidc'  => 'http://www.openarchives.org/OAI/2.0/oai_dc/'}

    puts 'loading system properties ...'
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']

    puts 'loading pid list ...'
    @pids = []
    f = File.open("pids.properties") or die "Unable to open file..."
    f.each_line {|line|
      if(line.include? 'york')
        @pids.push line.gsub("\n",'')
      end
    }
    f.close()
  end

  def checklabel()
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    for pid in @pids
      unique_labels = Set.new()

      puts 'checking custom labels for ' + pid + ' ...'
      relsint = conn.get '/fedora/objects/'+pid+'/datastreams/RELS-INT/content'
      dc = conn.get '/fedora/objects/'+pid+'/datastreams/DC/content'

      relsint_doc = Nokogiri::XML(relsint.body.to_s)
      dc_doc      = Nokogiri::XML(dc.body.to_s)

      labels = relsint_doc.xpath('/rdfs:RDF/rdfs:Description[contains(@rdfs:about,\'WAV\') or contains(@rdfs:about,\'AUDIO_MEDIUM\') or contains(@rdfs:about,\'AUDIO_LOW\')]/relint:hasDatastreamLabel', @namespaces)
      for label in labels
        # Check to ignore system DS Labels
        if label.text != 'WAV' and label.text != 'AUDIO_MEDIUM' and label.text != 'AUDIO_LOW'
          unique_labels << label.text
        end
      end

      dctitles = dc_doc.xpath('/oaidc:dc/dc:title', @namespaces)
      for dctitle in dctitles
        if unique_labels.include? dctitle   # if the title exists, no need to add
          unique_labels.delete dctitle
        end
      end

      dc_modified = false
      for newlabel in  unique_labels
        new_dc_title = Nokogiri::XML::Node.new('dc:title', dc_doc)
        new_dc_title.content = newlabel
        dc_doc.root << new_dc_title
        dc_modified = true
      end

      # if dc:title is modified (new dc:titles added), then remove the default one created by workflow
      if dc_modified == true
        dc_doc.search("//dc:title[.='Fedora object created by workflow.']").remove
        puts '  updating DC ...'
        conn.put  @protocol+"://"+@host+"/fedora/objects/"+pid+"/datastreams/DC", dc_doc.to_s, 'Content-Type' => 'text/xml'
      else
        puts '  no need to update DC ...'
      end
      #puts dc_doc.to_s

      relsint_modified = false
      # restore hasDatastreamLabels to the default (fixed) one as it will be used for access control
      if wavDS=relsint_doc.at('/rdfs:RDF/rdfs:Description[@rdfs:about=\'info:fedora/'+pid+'/WAV\']/relint:hasDatastreamLabel[.!=\'WAV\']', @namespaces)
        wavDS.content    = 'WAV'
        relsint_modified = true
      end
      if audioMediumDS=relsint_doc.at('/rdfs:RDF/rdfs:Description[@rdfs:about=\'info:fedora/'+pid+'/AUDIO_MEDIUM\']/relint:hasDatastreamLabel[.!=\'AUDIO_MEDIUM\']', @namespaces)
        audioMediumDS.content = 'AUDIO_MEDIUM'
        relsint_modified = true
      end
      if audioLowDS=relsint_doc.at('/rdfs:RDF/rdfs:Description[@rdfs:about=\'info:fedora/'+pid+'/AUDIO_LOW\']/relint:hasDatastreamLabel[.!=\'AUDIO_LOW\']', @namespaces)
        audioLowDS.content = 'AUDIO_LOW'
        relsint_modified = true
      end

      if relsint_modified == true
        puts '  updating RELS-INT ...'
        conn.put  @protocol+"://"+@host+"/fedora/objects/"+pid+"/datastreams/RELS-INT", relsint_doc.to_s, 'Content-Type' => 'text/xml'
      else
        puts '  no need to update RELS-INT ...'
      end
    end
  end
end

ccl = CheckCustomLabel.new()
ccl.checklabel()



