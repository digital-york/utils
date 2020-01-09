require_relative '../checkaudiocustomlabel/propertiesmanager.rb'

require 'zip'
require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'

class IrisDump
  def initialize()
    @namespaces = { 'iris'   => 'http://iris-database.org/iris',
                    'ds'     => 'http://www.fedora.info/definitions/1/0/access/',
                    'dsp'    => 'http://www.fedora.info/definitions/1/0/management/'}

    puts 'loading system properties ...'
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']
    @dumppath = @props['dumppath']
    @dumpfile = @props['dumpfile']

    @generatedfiles = Array.new

    puts 'loading pid list ...'
    @pids = load_pids()
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

  def dump()
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    total = @pids.length
    i = 1
    for pid in @pids
      puts 'Processing ' + pid + '['+i.to_s + ' / ' + total.to_s+']' +' ...'
      pidforsolr = pid.dup
      pidforsolr.sub! ':', '?'
      pidforfile = pid.dup
      pidforfile.sub! ':', '_'
      record = Nokogiri::XML('<record pid=\''+pid+'\'/>', nil, 'UTF-8')
      recordRoot = record.root

      puts '    Getting solr dump for ' + pid + ' ...'
      solrresponse = conn.get '/solr/select/?q=PID:'+ pidforsolr
      solrresponsedoc = solrresponse.body

      if not solrresponse.nil?
        # add solr xml response
        solrnode = Nokogiri::XML::Node.new('solr',record)
        recordRoot << solrnode
        solrnode.add_child(solrresponsedoc)

        # add associated files
        puts '    getting uploaded files ...'
        filesnode = Nokogiri::XML::Node.new('files',record)
        recordRoot << filesnode

        datastreamsresp = conn.get '/fedora/objects/'+pid+'/datastreams?format=xml'
        datastreamsdoc  = Nokogiri::XML(datastreamsresp.body.to_s)
        dss = datastreamsdoc.xpath("//ds:datastream[@label='INSTRUMENT']", @namespaces)
        if not dss.nil?
          for ds in dss
            dsid   = ds['dsid']
            dsmime = ds['mimeType']
            dsurl  = 'https://www.iris-database.org/iris/api/resource/' + pid + '/asset/' + dsid + "?download=true"
            filenode = Nokogiri::XML::Node.new('file',record)
            filenode['id']   = dsid
            filenode['mime'] = dsmime
            filenode['url']  = dsurl
            filesnode << filenode
          end
        else
          puts "    Cannot find any uploaded file for " + pid
        end
      else
        puts 'Error: cannot dump solr data!'
      end
      record.search("//arr[starts-with(@name,'iris.downloaders') or starts-with(@name,'iris2.downloaders')]").remove
      record.search("//arr[starts-with(@name,'vra.') or starts-with(@name,'vra2.')]").remove
      record.search("//arr[starts-with(@name,'acl.') or starts-with(@name,'acl2.')]").remove
      record.search("//arr[starts-with(@name,'rdf.') or starts-with(@name,'rdf2.')]").remove

      puts '    Saving to file ' + @dumppath + pidforfile + '.xml'
      File.write(@dumppath + pidforfile + '.xml', record.human)
      @generatedfiles << (pidforfile + '.xml')
      i = i+1
      if i%50 == 0
        puts 'Sleeping for 5s ...'
        sleep(5)
      end
    end

    puts 'Creating zip file ...'
    zipfilename = @dumpfile
    if File.exist? zipfilename
      File.delete(zipfilename)
    end
    Zip::File.open(zipfilename, Zip::File::CREATE) do |zipfile|
      for f in @generatedfiles
        zipfile.add(f, @dumppath + f)
      end
    end

  end
end

id = IrisDump.new()
id.dump()



