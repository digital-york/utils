require_relative 'propertiesmanager.rb'

require 'roo'
require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'
require 'colorize'

# NB: This script expects that there are ONLY SPECIAL COLLECTION texts in the notes field.
#     If there are any additional texts, e.g. author entered original notes text, and then IRIS admins entered special collection text,
#     manual checks are needed as the patterns of the text in the notes fields are hard to identify.

class BatchUpdater
  # @namespaces = { 'iris'   => 'http://iris-database.org/iris'}

  def initialize()
    @IRIS_NS    = 'http://iris-database.org/iris'
    print 'loading system properties ... '
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']
    @path     = @props['path']

    @props2    = PropertiesManager.new("excel_settings.yaml").getPropertiesHash()
    @sheetname= @props2['sheetname']

    @column_author1                       = @props2['column_author1'].to_i
    @column_author2                       = @props2['column_author2'].to_i
    @column_author3                       = @props2['column_author3'].to_i
    @column_author4                       = @props2['column_author4'].to_i
    @column_author5                       = @props2['column_author5'].to_i
    @column_author6                       = @props2['column_author6'].to_i
    @column_instrumenttype1               = @props2['column_instrumenttype1'].to_i
    @column_instrumenttype2               = @props2['column_instrumenttype2'].to_i
    @column_reseracharea1                 = @props2['column_reseracharea1'].to_i
    @column_reseracharea2                 = @props2['column_reseracharea2'].to_i
    @column_reseracharea3                 = @props2['column_reseracharea3'].to_i
    @column_typeoffile1                   = @props2['column_typeoffile1'].to_i
    @column_typeoffile2                   = @props2['column_typeoffile2'].to_i
    @column_software                      = @props2['column_software'].to_i
    @column_instrumenttitle               = @props2['column_instrumenttitle'].to_i
    @column_notes                         = @props2['column_notes'].to_i
    @column_participanttype1              = @props2['column_participanttype1'].to_i
    @column_participanttype2              = @props2['column_participanttype2'].to_i
    @column_language1                     = @props2['column_language1'].to_i
    @column_language2                     = @props2['column_language2'].to_i
    @column_publication1_type             = @props2['column_publication1_type'].to_i
    @column_publication1_author1          = @props2['column_publication1_author1'].to_i
    @column_publication1_author2          = @props2['column_publication1_author2'].to_i
    @column_publication1_author3          = @props2['column_publication1_author3'].to_i
    @column_publication1_author4          = @props2['column_publication1_author4'].to_i
    @column_publication1_author5          = @props2['column_publication1_author5'].to_i
    @column_publication1_author6          = @props2['column_publication1_author6'].to_i
    @column_publication1_title            = @props2['column_publication1_title'].to_i
    @column_publication1_journal          = @props2['column_publication1_journal'].to_i
    @column_publication1_date             = @props2['column_publication1_date'].to_i
    @column_publication1_volume           = @props2['column_publication1_volume'].to_i
    @column_publication1_issue_no         = @props2['column_publication1_issue_no'].to_i
    @column_publication1_page_number_from = @props2['column_publication1_page_number_from'].to_i
    @column_publication1_page_number_to   = @props2['column_publication1_page_number_to'].to_i
    @column_publication1_doi              = @props2['column_publication1_doi'].to_i
    @column_email                         = @props2['column_email'].to_i
    puts ' done.'
  end

  def update()
    conn = Faraday.new(:url => @protocol + "://" + @host) do |c|
      c.use Faraday::Request::UrlEncoded
      #c.use Faraday::Response::Logger
      c.use Faraday::Adapter::NetHttp
    end
    conn.basic_auth(@admin, @password)

    Dir.foreach(@path) do |filename|
      next if filename == '.' or filename == '..'
      puts 'Analyzing ' + filename + ' ... '
      excel_to_iris_xmls(@path + filename)
    end

  end

  def excel_to_iris_xmls(excel_file_name)
    xsl = Roo::Spreadsheet.open(excel_file_name)

    sheet = xsl.sheet(@sheetname)

    if !sheet.nil?
      last_row    = sheet.last_row
      last_column = sheet.last_column

      if !last_row.nil? and !last_column.nil?
        for row in 2..last_row
          author1                       = sheet.cell(row, @column_author1)

          if author1.nil? or author1.strip==''
            next
          end

          author2                       = sheet.cell(row, @column_author2)
          author3                       = sheet.cell(row, @column_author3)
          author4                       = sheet.cell(row, @column_author4)
          author5                       = sheet.cell(row, @column_author5)
          author6                       = sheet.cell(row, @column_author6)
          instrumenttype1               = sheet.cell(row, @column_instrumenttype1)
          instrumenttype2               = sheet.cell(row, @column_instrumenttype2)
          reseracharea1                 = sheet.cell(row, @column_reseracharea1)
          reseracharea2                 = sheet.cell(row, @column_reseracharea2)
          reseracharea3                 = sheet.cell(row, @column_reseracharea3)
          typeoffile1                   = sheet.cell(row, @column_typeoffile1)
          typeoffile2                   = sheet.cell(row, @column_typeoffile2)
          software                      = sheet.cell(row, @column_software)
          instrumenttitle               = sheet.cell(row, @column_instrumenttitle)
          notes                         = sheet.cell(row, @column_notes)
          participanttype1              = sheet.cell(row, @column_participanttype1)
          participanttype2              = sheet.cell(row, @column_participanttype2)
          language1                     = sheet.cell(row, @column_language1)
          language2                     = sheet.cell(row, @column_language2)
          publication1_type             = sheet.cell(row, @column_publication1_type)
          publication1_author1          = sheet.cell(row, @column_publication1_author1)
          publication1_author2          = sheet.cell(row, @column_publication1_author2)
          publication1_author3          = sheet.cell(row, @column_publication1_author3)
          publication1_author4          = sheet.cell(row, @column_publication1_author4)
          publication1_author5          = sheet.cell(row, @column_publication1_author5)
          publication1_author6          = sheet.cell(row, @column_publication1_author6)
          publication1_title            = sheet.cell(row, @column_publication1_title)
          publication1_journal          = sheet.cell(row, @column_publication1_journal)
          publication1_date             = sheet.cell(row, @column_publication1_date)
          publication1_volume           = sheet.cell(row, @column_publication1_volume)
          publication1_issue_no         = sheet.cell(row, @column_publication1_issue_no)
          publication1_page_number_from = sheet.cell(row, @column_publication1_page_number_from)
          publication1_page_number_to   = sheet.cell(row, @column_publication1_page_number_to)
          publication1_doi              = sheet.cell(row, @column_publication1_doi)
          email                         = sheet.cell(row, @column_email)

=begin
          puts author1

            puts author2
          end
          if !author3.nil?
            puts author3
          end
          if !author4.nil?
            puts author4
          end
          if !author5.nil?
            puts author5
          end
          if !author6.nil?
            puts author6
          end
=end
          builder = Nokogiri::XML::Builder.new do |xml|
            xml['iris'].iris('xmlns:iris' => @IRIS_NS) {
              xml['iris'].instrument() {
                xml['iris'].creator() {
                  xml['iris'].fullName  author1.strip
                  xml['iris'].lastName  author1.split(',')[0].strip
                  xml['iris'].firstName author1.split(',')[1].strip
                }
                if !author2.nil?
                  xml['iris'].creator() {
                    xml['iris'].fullName  author2.strip
                    xml['iris'].lastName  author2.split(',')[0].strip
                    xml['iris'].firstName author2.split(',')[1].strip
                  }
                end
                if !author3.nil?
                  xml['iris'].creator() {
                    xml['iris'].fullName  author3.strip
                    xml['iris'].lastName  author3.split(',')[0].strip
                    xml['iris'].firstName author3.split(',')[1].strip
                  }
                end
                if !author4.nil?
                  xml['iris'].creator() {
                    xml['iris'].fullName  author4.strip
                    xml['iris'].lastName  author4.split(',')[0].strip
                    xml['iris'].firstName author4.split(',')[1].strip
                  }
                end
                if !author5.nil?
                  xml['iris'].creator() {
                    xml['iris'].fullName  author5.strip
                    xml['iris'].lastName  author5.split(',')[0].strip
                    xml['iris'].firstName author5.split(',')[1].strip
                  }
                end
                if !author6.nil?
                  xml['iris'].creator() {
                    xml['iris'].fullName  author6.strip
                    xml['iris'].lastName  author6.split(',')[0].strip
                    xml['iris'].firstName author6.split(',')[1].strip
                  }
                end
              }
            }
          end

          puts builder.to_xml

        end
      else
        puts 'Seems no data in ' + sheet_name
      end
    end

  end

end

bu = BatchUpdater.new()
bu.update()
