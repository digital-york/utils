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
  @namespaces = { 'iris'   => 'http://iris-database.org/iris'}

  def initialize()
    print 'loading system properties ... '
    @props    = PropertiesManager.new("system.yaml").getPropertiesHash()
    @protocol = @props['protocol']
    @host     = @props['host']
    @admin    = @props['admin']
    @password = @props['password']
    @path     = @props['path']
    @sheetname= @props['sheetname']

    @column_author1                       = @props['column_author1']
    @column_author2                       = @props['column_author2']
    @column_author3                       = @props['column_author3']
    @column_author4                       = @props['column_author4']
    @column_author5                       = @props['column_author5']
    @column_author6                       = @props['column_author6']
    @column_instrumenttype1               = @props['column_instrumenttype1']
    @column_instrumenttype2               = @props['column_instrumenttype2']
    @column_reseracharea1                 = @props['column_reseracharea1']
    @column_reseracharea2                 = @props['column_reseracharea2']
    @column_reseracharea3                 = @props['column_reseracharea3']
    @column_typeoffile1                   = @props['column_typeoffile1']
    @column_typeoffile2                   = @props['column_typeoffile2']
    @column_software                      = @props['column_software']
    @column_instrumenttitle               = @props['column_instrumenttitle']
    @column_notes                         = @props['column_notes']
    @column_participanttype1              = @props['column_participanttype1']
    @column_participanttype2              = @props['column_participanttype2']
    @column_language1                     = @props['column_language1']
    @column_language2                     = @props['column_language2']
    @column_publication1_type             = @props['column_publication1_type']
    @column_publication1_author1          = @props['column_publication1_author1']
    @column_publication1_author2          = @props['column_publication1_author2']
    @column_publication1_author3          = @props['column_publication1_author3']
    @column_publication1_author4          = @props['column_publication1_author4']
    @column_publication1_author5          = @props['column_publication1_author5']
    @column_publication1_author6          = @props['column_publication1_author6']
    @column_publication1_title            = @props['column_publication1_title']
    @column_publication1_journal          = @props['column_publication1_journal']
    @column_publication1_date             = @props['column_publication1_date']
    @column_publication1_volume           = @props['column_publication1_volume']
    @column_publication1_issue_no         = @props['column_publication1_issue_no']
    @column_publication1_page_number_from = @props['column_publication1_page_number_from']
    @column_publication1_page_number_to   = @props['column_publication1_page_number_to']
    @column_publication1_doi              = @props['column_publication1_doi']
    @column_email                         = @props['column_email']
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
          #instype = sheet.cell(row, 7)
          author1                       = sheet.cell(row, @column_author1)
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
          @column_typeoffile1                   = sheet.cell(row,)
          @column_typeoffile2                   = sheet.cell(row,)
          @column_software                      = sheet.cell(row,)
          @column_instrumenttitle               = sheet.cell(row,)
          @column_notes                         = sheet.cell(row,)
          @column_participanttype1              = sheet.cell(row,)
          @column_participanttype2              = sheet.cell(row,)
          @column_language1                     = sheet.cell(row,)
          @column_language2                     = sheet.cell(row,)
          @column_publication1_type             = sheet.cell(row,)
          @column_publication1_author1          = sheet.cell(row,)
          @column_publication1_author2          = sheet.cell(row,)
          @column_publication1_author3          = sheet.cell(row,)
          @column_publication1_author4          = sheet.cell(row,)
          @column_publication1_author5          = sheet.cell(row,)
          @column_publication1_author6          = sheet.cell(row,)
          @column_publication1_title            = sheet.cell(row,)
          @column_publication1_journal          = sheet.cell(row,)
          @column_publication1_date             = sheet.cell(row,)
          @column_publication1_volume           = sheet.cell(row,)
          @column_publication1_issue_no         = sheet.cell(row,)
          @column_publication1_page_number_from = sheet.cell(row,)
          @column_publication1_page_number_to   = sheet.cell(row,)
          @column_publication1_doi              = sheet.cell(row,)
          @column_email                         = sheet.cell(row,)

          next if (instype.nil? or instype == '')
          puts instype

          for col in 1..last_column
            v = sheet.cell(row, col)

            if v.nil?
#              puts "NIL"
            else
#              puts "["+row.to_s+","+col.to_s+"]: " + sheet.cell(row, col).to_s
            end
          end
        end
      else
        puts 'Seems no data in ' + sheet_name
      end
    end

  end

end

bu = BatchUpdater.new()
bu.update()
