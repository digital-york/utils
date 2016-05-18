require_relative '../checkaudiocustomlabel/propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class IrisDump
  def initialize()
    @namespaces = { 'iris'   => 'http://iris-database.org/iris'}

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

  def dump()
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)
    dumpdoc = Nokogiri::XML('<irisdump></irisdump>')
    dumproot = dumpdoc.root
    puts '==============='
    #puts dumpdoc.to_xml

    for pid in @pids
      record = Nokogiri::XML::Node.new('record',dumpdoc)
      # add pid properties
      record['pid'] = pid
      dumproot << record

      puts 'getting solr dump for ' + pid + ' ...'
      solrresponse = conn.get '/solr/select/?q=PID:'+ (pid.sub! ':', '?')
      solrresponsedoc = solrresponse.body

      if not solrresponse.nil?
        # add solr xml response
        solrnode = Nokogiri::XML::Node.new('solr',dumpdoc)
        record << solrnode
        solrnode.add_child(solrresponsedoc)

        # add associated files
        puts 'getting uploaded files ...'
        filesnode = Nokogiri::XML::Node.new('files',dumpdoc)
        record << filesnode


        break
      end
#        solr_doc = Nokogiri::XML(solrresponse.body.to_s)
    end

    # removing all iris.downloaders.* and iris2.downloaders.* information
    dumpdoc.search("//arr[starts-with(@name,'iris.downloaders') or starts-with(@name,'iris2.downloaders')]").remove

    puts dumpdoc.to_xml
  end
end

id = IrisDump.new()
id.dump()



