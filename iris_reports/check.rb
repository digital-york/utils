require_relative '../checkaudiocustomlabel/propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class IrisReport
  def initialize()
    puts 'loading system properties ...'
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']

    puts 'loading pid list ...'
    @pids = []

    load_data(true)

  end

  def generate_report()
    puts 'Loading data...'

    puts 'Generating reports'
  end

  def load_data(show_progress_details=false)
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    total = @pids.length
    i = 1
    total_downloads = 0

    for pid in @pids
      if show_progress_details
        puts '    Processing ' + pid + '['+i.to_s + ' / ' + total.to_s+']' +' ...'
      else
        print '.'
      end
      pidforsolr = pid.dup
      pidforsolr.sub! ':', '?'

      solrresponse = conn.get '/solr/select/?q=PID:'+ pidforsolr
      solrresponsedoc = solrresponse.body

      unless solrresponsedoc.nil?
        solrdoc  = Nokogiri::XML(solrresponsedoc.to_s)
        dss = solrdoc.xpath("/response/result/doc/arr[@name='iris.downloaders.uniquecount']/str/text()")
        total_downloads = total_downloads + dss.to_s.to_i
      else
        puts 'Error: cannot search in solr!'
      end

      i = i+1

      if i%100==0
        sleep(1)
      end
    end

    puts "From Solr: #{total_downloads}"

  end

end

ir = IrisReport.new()
#ir.generate_report()



