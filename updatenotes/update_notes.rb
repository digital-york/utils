require_relative 'propertiesmanager.rb'

require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'
require 'colorize'

# NB: This script expects that there are ONLY SPECIAL COLLECTION texts in the notes field.
#     If there are any additional texts, e.g. author entered original notes text, and then IRIS admins entered special collection text,
#     manual checks are needed as the patterns of the text in the notes fields are hard to identify.

class UpdateNotes
  @namespaces = { 'iris'   => 'http://iris-database.org/iris'}

  def initialize()
    @SPR_YEARS = '1995-2016'
    @GJT_YEARS = '1976-2016'

    puts 'loading system properties ...'
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']
    @pids = []
    f = File.open("pids.properties") or die "Unable to open file..."
    f.each_line {|line|
      if(line.include? 'york')
        @pids.push line.gsub("\n",'').gsub("\r",'')
      end
    }
    f.close()
  end

  def update_notes()
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

      puts "    Checking notes field ... "
      iris_notes_element = iris_doc.at_xpath("/iris:iris/iris:instrument/iris:notes")
      if iris_notes_element.nil? or iris_notes_element.text.nil? or iris_notes_element.text == ''
        puts '      EMPTY, bypass.'.colorize(:color => :red)
      else
        iris_notes_text    = iris_notes_element.text
        if iris_notes_text.include? 'SPECIAL COLLECTION'
          puts '      Analyzing notes in ' + pid
          # years = extract_year(iris_doc)
          updated_text = get_updated_text(iris_notes_text)
          iris_notes_element.content = updated_text
          changed = true
          puts "      " + updated_text
        else
          puts '      NON special collection, bypass.'.colorize(:color => :red)
        end
      end

      # NOW, update Fedora datastream
      if changed == true
        print '     Updating notes field ... '.colorize(:color => :green)

        resp = conn.put '/fedora/objects/'+pid+'/datastreams/IRIS', iris_doc.to_xml do |req|
          req.headers['Content-Type'] = 'text/xml'
        end
        puts 'done.'

        print '     Updating DC ... '.colorize(:color => :green)
        xsl = Nokogiri::XSLT(File.read("iris2dc.xsl"))
        dc  = xsl.apply_to(iris_doc)
        resp = conn.put '/fedora/objects/'+pid+'/datastreams/DC', dc do |req|
          req.headers['Content-Type'] = 'text/xml'
        end
        puts 'done.'
      end
    end
  end

  def get_updated_text(str)
    result = ''

    as = str.split(/SPECIAL COLLECTION/)
    index = 0
    as.each do |a|
      if !a.nil? and a!=''
        a = 'SPECIAL COLLECTION' + a
        if a.start_with? 'SPECIAL COLLECTION - SELF-PACED READING'
          a = 'SPECIAL COLLECTION - SELF-PACED READING. ' + @SPR_YEARS
        elsif a.start_with? 'SPECIAL COLLECTION - GRAMMATICALITY/ACCEPTABILITY JUDGEMENT TESTS'
          a = 'SPECIAL COLLECTION - GRAMMATICALITY/ACCEPTABILITY JUDGEMENT TESTS. ' + @GJT_YEARS
        end
        if index == as.size - 1
          result = result + a + '.'
        else
          result = result + a + ', '
        end
      end
      index = index + 1
    end
    result
  end

end

un = UpdateNotes.new()
un.update_notes()




