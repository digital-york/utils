require_relative 'propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'
require 'colorize'

class CheckApprovedInsType
  def initialize()
    @namespaces = { 'iris'   => 'http://iris-database.org/iris'}

    @instrument_types = Set.new
    dddoc = Nokogiri::XML(File.open("dd/commons.xml"))
    ins_types = dddoc.xpath("/IRIS_Data_Dict/instrument/typeOfInstruments//type")
    for ins_type in ins_types
      @instrument_types << ins_type.attr('label')
      #puts 'Loaded ' + ins_type.attr('label')
    end

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

  def checkinstype()
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    for pid in @pids
      unique_labels = Set.new()

      puts 'checking primary instrument type for ' + pid + ' ...'
      iris = conn.get '/fedora/objects/'+pid+'/datastreams/IRIS/content'

      iris_doc = Nokogiri::XML(iris.body.to_s)

      primaryInsTypes = iris_doc.xpath("/iris:iris/iris:instrument/iris:instrumentType[@primary='999']", @namespaces)
      for primaryInsType in primaryInsTypes
      #puts primaryInsType.nil?
        unless primaryInsType.nil?
           if @instrument_types.include? primaryInsType.attr('newValue')
               puts 'Problem -> ' + primaryInsType.attr('newValue').red
           end
        end 
      end
    end
  end
end

ci = CheckApprovedInsType.new()
ci.checkinstype()



