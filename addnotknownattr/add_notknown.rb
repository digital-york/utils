require_relative 'propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'
require 'colorize'

class AddNotKnown
  @namespaces = { 'iris'   => 'http://iris-database.org/iris'}

  def initialize()
    @ID_RANGE_START = 933018
    @ID_RANGE_END   = 933059

    puts 'loading system properties ...'
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']
    @pids = []

    for p in @ID_RANGE_START..@ID_RANGE_END
      @pids.push 'york:' + p.to_s
    end

  end

  def add_notknown()
    pids = @pids

    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    pids.each do |pid|
      changed = false
      puts 'Processing ' + pid
      print "    Reading IRIS datastream ... "
      iris = conn.get '/fedora/objects/'+pid+'/datastreams/IRIS/content'
      iris_doc = Nokogiri::XML(iris.body.to_s)
      puts 'done.'

      puts "    Checking pageFrom field ... "
      iris_pagefrom_element = iris_doc.at_xpath("/iris:iris/iris:relatedItems/iris:relatedItem[@type='publication']/iris:pageFrom")
      if iris_pagefrom_element.nil? or iris_pagefrom_element.text.nil?
        puts '      EMPTY, bypass.'.colorize(:color => :red)
      elsif iris_pagefrom_element.text == ''
        iris_pagefrom_element['notknown'] = 'true'
        changed = true
      else
        iris_pagefrom_element['notknown'] = 'false'
        changed = true
      end

      # NOW, update Fedora datastream
      if changed == true
        print '     Updating pageFrom field ... '.colorize(:color => :green)

        resp = conn.put '/fedora/objects/'+pid+'/datastreams/IRIS', iris_doc.to_xml do |req|
          req.headers['Content-Type'] = 'text/xml'
        end
        puts 'done.'
      end
    end
  end

end

ank = AddNotKnown.new()
ank.add_notknown()

