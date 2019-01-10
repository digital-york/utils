require_relative '../checkaudiocustomlabel/propertiesmanager.rb'

require 'zip'
require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class IrisStatisticsCheck
  def initialize()
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

  def check_via_solr(show_progress_details=false)
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

  def check_via_fedora(show_progress_details=false)
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    total = @pids.length
    i = 1
    total_downloads = 0

    @pids.each do |p|
      if show_progress_details
        puts "Checking #{p.to_s.strip}: [#{i.to_s} / #{total.to_s}] ..."
      else
        print '.'
      end
      downloader_url = "/fedora/objects/#{p.to_s.strip}/datastreams/DOWNLOADER/content"

      downloader       = conn.get downloader_url
      downloader_doc   = Nokogiri::XML(downloader.body.to_s)
      downloader_count = downloader_doc.xpath("count(/downloaders/downloader[@duplicate='false'])")
      #puts downloader_count.to_s.to_i
      total_downloads = total_downloads + downloader_count.to_s.to_i

      i = i+1

      if i%100==0
        sleep(1)
      end
    end

    puts "From Fedora: #{total_downloads}"

  end

end

isc = IrisStatisticsCheck.new()
isc.check_via_solr()
#isc.check_via_fedora()



