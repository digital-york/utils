require_relative '../checkaudiocustomlabel/propertiesmanager.rb'

require 'date'
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
    @pids = load_pids()
    @monthly_upload_report = {}
    @monthly_download_report = {}
  end

  # Use Fedora RI search to get IRIS pid list
  def load_pids()
    pids = []

    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    ri_url = "/fedora/risearch"
    ri_query = "
      select $s
      from <#ri>
      where
      ($s <info:fedora/fedora-system:def/model#hasModel> <info:fedora/york:CModel-Iris>)
    "
    riresults = conn.post ri_url, {'lang' => 'itql',
                                   'format' => 'Sparql',
                                   'query' => ri_query
                                   }

    ri_results_doc = Nokogiri::XML(riresults.body.to_s)
    pids_elements  = ri_results_doc.xpath('/sp:sparql/sp:results/sp:result/sp:s/@uri', 'sp' => 'http://www.w3.org/2001/sw/DataAccess/rf1/result')
    for pe in pids_elements
      pids << (pe.text.sub! 'info:fedora/','')
    end
    pids
  end

  def load_data(show_progress_details=true)
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      c.use Faraday::Adapter::NetHttp
    end

    puts 'Processing data...'
    total = @pids.length
    i = 1
    for pid in @pids
      if show_progress_details
        puts "    Processing #{pid} [#{i} / #{total}] ..."
      else
        print '.'
      end
      pidforsolr = pid.dup
      pidforsolr.sub! ':', '?'
      solrresponse = conn.get '/solr/select/?q=PID:'+ pidforsolr
      solrresponsedoc = solrresponse.body

      unless solrresponsedoc.nil?
        solrdoc  = Nokogiri::XML(solrresponsedoc.to_s)
        created_date = solrdoc.xpath("/response/result/doc/date[@name='fgs.createdDate']/text()")
        key = DateTime.parse(created_date.to_s).strftime('%Y%m')
        if @monthly_upload_report[key].nil?
          @monthly_upload_report[key] = [pid]
        else
          @monthly_upload_report[key] << pid
        end

        # Get downloader information
        downloaders_time = solrdoc.xpath("/response/result/doc/arr[starts-with(@name,'iris.downloaders.time')]/str/text()")
        for downloader_time in downloaders_time
          key = DateTime.parse(downloader_time.to_s).strftime('%Y%m')
          if @monthly_download_report[key].nil?
            @monthly_download_report[key] = 1
          else
            @monthly_download_report[key] = @monthly_download_report[key].to_i + 1
          end
        end

      else
        puts 'Error: cannot search in solr!'
      end

      i = i+1

      if i%100==0
        sleep(1)
      end
      # if i>1
      #   break
      # end
    end
  end

  def generate_report()
    puts 'Upload report'
    puts '-----------------'
    @monthly_upload_report.each do |k,v|
      puts "#{k},#{v.length}"
    end
    puts

    puts 'Download report'
    puts '-----------------'
    @monthly_download_report.each do |k,v|
      puts "#{k},#{v}"
    end

  end
end

ir = IrisReport.new()
ir.load_data()
ir.generate_report()



