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
    @dumpfile = @props['dumpfile']

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
    dumpdoc = Nokogiri::XML('<irisdump></irisdump>', nil, 'UTF-8')
    dumproot = dumpdoc.root
    puts '==============='
    #puts dumpdoc.to_xml

    total = @pids.length

    i = 1
    for pid in @pids
      puts 'Processing ' + pid + '['+i.to_s + ' / ' + total.to_s+']' +' ...'
      pidforsolr = pid.dup
      pidforsolr.sub! ':', '?'
      record = Nokogiri::XML::Node.new('record',dumpdoc)
      # add pid properties
      record['pid'] = pid
      dumproot << record

      puts '    Getting solr dump for ' + pid + ' ...'
      solrresponse = conn.get '/solr/select/?q=PID:'+ pidforsolr
      solrresponsedoc = solrresponse.body

      if not solrresponse.nil?
        # add solr xml response
        solrnode = Nokogiri::XML::Node.new('solr',dumpdoc)
        record << solrnode
        solrnode.add_child(solrresponsedoc)

        # add associated files
        puts '    getting uploaded files ...'
        filesnode = Nokogiri::XML::Node.new('files',dumpdoc)
        record << filesnode

        datastreamsresp = conn.get '/fedora/objects/'+pid+'/datastreams?format=xml'
        datastreamsdoc  = Nokogiri::XML(datastreamsresp.body.to_s)
        dss = datastreamsdoc.xpath("//ds:datastream[@label='INSTRUMENT']", @namespaces)
        if not dss.nil?
          for ds in dss
            dsid = ds['dsid']
            dsmime = ds['mimeType']
            datastreamprofileresp = conn.get '/fedora/objects/'+pid+'/datastreams/'+dsid+'?format=xml'
            datastreamprofiledoc  = Nokogiri::XML(datastreamprofileresp.body.to_s)

            dslocation_elts = datastreamprofiledoc.xpath('/dsp:datastreamProfile/dsp:dsLocation', @namespaces)
            if not dslocation_elts.nil?
              for dslocation_elt in dslocation_elts
                dslocation = dslocation_elt.text
                filenode = Nokogiri::XML::Node.new('file',dumpdoc)
                filenode['id'] = dsid
                filenode['mime'] = dsmime
                filenode['url']  = dslocation
                filesnode << filenode
              end
            end
          end
        else
          puts "    Cannot find any uploaded file for " + pid
        end

        i = i+1
        if i>2
          break
        end
        #break
      end
#        solr_doc = Nokogiri::XML(solrresponse.body.to_s)
    end

    # removing all iris.downloaders.* and iris2.downloaders.* information
    dumpdoc.search("//arr[starts-with(@name,'iris.downloaders') or starts-with(@name,'iris2.downloaders')]").remove
    dumpdoc.search("//arr[starts-with(@name,'vra.') or starts-with(@name,'vra2.')]").remove
    dumpdoc.search("//arr[starts-with(@name,'acl.') or starts-with(@name,'acl2.')]").remove
    dumpdoc.search("//arr[starts-with(@name,'rdf.') or starts-with(@name,'rdf2.')]").remove

    puts 'Saving to file ' + @dumpfile
    File.write(@dumpfile, dumpdoc.human)

    zipfilename = @dumpfile + '.zip'
    Zip::File.open(zipfilename, Zip::File::CREATE) do |zipfile|
      zipfile.add('solrdump.xml', @dumpfile)
    end

    #puts dumpdoc.human
  end
end

id = IrisDump.new()
id.dump()



