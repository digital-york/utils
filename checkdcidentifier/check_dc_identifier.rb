require_relative 'propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class CheckDcIdentifier
  def initialize()
    @namespaces = { 'dc'     => 'http://purl.org/dc/elements/1.1/',
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

  def checkdcidentifier()
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    for pid in @pids
      unique_labels = Set.new()

      puts 'checking dc:identifier for ' + pid + ' ...'
      dc = conn.get '/fedora/objects/'+pid+'/datastreams/DC/content'

	  needtochange = true
      dc_doc      = Nokogiri::XML(dc.body.to_s)
      dcidentifiers = dc_doc.xpath('/oaidc:dc/dc:identifier', @namespaces)
      for dcidentifier in dcidentifiers
        if dcidentifier.content == pid
          needtochange = false
        end
      end

      if needtochange == true
	    puts 'updating DC'
	  else
	    puts 'no need to update'
	  end
    end
  end
end

cdi = CheckDcIdentifier.new()
cdi.checkdcidentifier()



