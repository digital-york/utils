require_relative 'propertiesmanager.rb'

require 'roo'
require 'faraday'
require "nokogiri"
require 'nokogiri-pretty'
require 'colorize'
require 'gmail'

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
    @dd_commons_file = @props['dd_commons']
    @dd_authors_file = @props['dd_authors']
    @dd_languages_file = @props['dd_languages']

    @gmail_user            = @props['gmail_user']
    @gmail_pass            = @props['gmail_pass']
    @gmail_to              = @props['gmail_to']
    @gmail_default_subject = @props['gmail_default_subject']

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
    @column_other_software_url            = @props2['column_other_software_url'].to_i
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

    print 'loading data dictionaries ... '
    @dd_commons_doc   = Nokogiri::XML(File.open(@dd_commons_file))
    @dd_authors_doc   = Nokogiri::XML(File.open(@dd_authors_file))
    @dd_languages_doc = Nokogiri::XML(File.open(@dd_languages_file))

    puts ' done.'
  end

  def is_author_in_dd(author)
    a = @dd_authors_doc.at_xpath("/authors/author[.='"+author+"']")
    !a.nil?
  end

  def dd_value_from_xpath(xpath)
    v = @dd_commons_doc.at_xpath(xpath)
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
      iris_metadata = excel_to_iris_xmls(@path + filename)
      iris_metadata.each do |iris|
        puts '--------------------------'
        puts iris
      end
    end

    #send_via_gmail(@gmail_user,@gmail_pass,@gmail_to,@gmail_default_subject,"BODYYYYYYYYYY",nil)
  end

  def excel_to_iris_xmls(excel_file_name)
    iris_metadata = Set.new

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
          other_software_url            = sheet.cell(row, @column_other_software_url)
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

          builder = Nokogiri::XML::Builder.new do |xml|
            xml['iris'].iris('xmlns:iris' => @IRIS_NS) {

              ###########################################################################
              # instrument
              xml['iris'].instrument() {

                # processing authors
                type = 'new'
                if is_author_in_dd(author1.strip)
                  type = 'auto'
                end
                xml['iris'].creator(:type => type) {
                  xml['iris'].fullName  author1.strip
                  xml['iris'].lastName  author1.split(',')[0].strip
                  xml['iris'].firstName author1.split(',')[1].strip
                }
                if !author2.nil?
                  type = 'new'
                  if is_author_in_dd(author2.strip)
                    type = 'auto'
                  end
                  xml['iris'].creator(:type => type) {
                    xml['iris'].fullName  author2.strip
                    xml['iris'].lastName  author2.split(',')[0].strip
                    xml['iris'].firstName author2.split(',')[1].strip
                  }
                end
                if !author3.nil?
                  type = 'new'
                  if is_author_in_dd(author3.strip)
                    type = 'auto'
                  end
                  xml['iris'].creator(:type => type) {
                    xml['iris'].fullName  author3.strip
                    xml['iris'].lastName  author3.split(',')[0].strip
                    xml['iris'].firstName author3.split(',')[1].strip
                  }
                end
                if !author4.nil?
                  type = 'new'
                  if is_author_in_dd(author4.strip)
                    type = 'auto'
                  end
                  xml['iris'].creator(:type => type) {
                    xml['iris'].fullName  author4.strip
                    xml['iris'].lastName  author4.split(',')[0].strip
                    xml['iris'].firstName author4.split(',')[1].strip
                  }
                end
                if !author5.nil?
                  type = 'new'
                  if is_author_in_dd(author5.strip)
                    type = 'auto'
                  end
                  xml['iris'].creator(:type => type) {
                    xml['iris'].fullName  author5.strip
                    xml['iris'].lastName  author5.split(',')[0].strip
                    xml['iris'].firstName author5.split(',')[1].strip
                  }
                end
                if !author6.nil?
                  type = 'new'
                  if is_author_in_dd(author6.strip)
                    type = 'auto'
                  end
                  xml['iris'].creator(:type => type) {
                    xml['iris'].fullName  author6.strip
                    xml['iris'].lastName  author6.split(',')[0].strip
                    xml['iris'].firstName author6.split(',')[1].strip
                  }
                end

                # processing instrument types
                if !instrumenttype1.nil?
                  xpath = "/IRIS_Data_Dict/instrument/typeOfInstruments//type[@label='"+instrumenttype1.strip+"']/@value"
                  v = dd_value_from_xpath(xpath)
                  newValue = nil
                  if v.nil?
                    v       = '999'
                    newValue = instrumenttype1.strip
                  end
                  primary = v # assuming first ins type is the primary type

                  if !instrumenttype2.nil?
                    xpath = "/IRIS_Data_Dict/instrument/typeOfInstruments//type[@label='"+instrumenttype2.strip+"']/@value"
                    v2 = dd_value_from_xpath(xpath)
                    if !v2.nil?
                      v = v.to_s + ' ' + v2.to_s
                    end
                  end

                  if newValue.nil?
                    xml['iris'].instrumentType(:primary=>primary) {
                      xml.text(v)
                    }
                  else
                    xml['iris'].instrumentType(:primary=>primary, :newValue=>newValue) {
                      xml.text(v)
                    }
                  end
                end

                # processing research areas
                if !reseracharea1.nil?
                  xpath = "/IRIS_Data_Dict/instrument/researchAreas//researchArea[@label='"+reseracharea1.strip+"']/@value"
                  v = dd_value_from_xpath(xpath)
                  newValue = nil
                  if v.nil?
                    v       = '999'
                    newValue = reseracharea1.strip
                  end

                  if !reseracharea2.nil?
                    xpath = "/IRIS_Data_Dict/instrument/researchAreas//researchArea[@label='"+reseracharea2.strip+"']/@value"
                    v2 = dd_value_from_xpath(xpath)
                    if !v2.nil?
                      v = v.to_s + ' ' + v2.to_s
                    end
                  end

                  if !reseracharea3.nil?
                    xpath = "/IRIS_Data_Dict/instrument/researchAreas//researchArea[@label='"+reseracharea3.strip+"']/@value"
                    v3 = dd_value_from_xpath(xpath)
                    if !v3.nil?
                      v = v.to_s + ' ' + v3.to_s
                    end
                  end

                  if newValue.nil?
                    xml['iris'].researchArea() {
                      xml.text(v)
                    }
                  else
                    xml['iris'].researchArea(:newValue=>newValue) {
                      xml.text(v)
                    }
                  end
                end

                # Processing type of file
                # processing research areas
                if !typeoffile1.nil?
                   xpath = "/IRIS_Data_Dict/instrument/types/type[@label='"+typeoffile1.strip+"']/@value"
                   v = dd_value_from_xpath(xpath)

                   typeoffile = typeoffile1.strip
                   if !typeoffile2.nil?
                     xpath = "/IRIS_Data_Dict/instrument/types/type[@label='"+typeoffile2.strip+"']/@value"
                     v2 = dd_value_from_xpath(xpath)
                     v = v.to_s + ' ' + v2.to_s.strip
                   end
                   xml['iris'].type() {
                     xml.text(v)
                   }

                   # Add software details if 'Software' is ticked
                   if v.include? 'Software' and !software.nil?
                     xpath = "/IRIS_Data_Dict/instrument/required_software/software[@label='"+software.strip+"']/@value"
                     v = dd_value_from_xpath(xpath)

                     newValue = nil
                     href     = nil

                     if v.nil?
                       v = '999'
                       newValue = software.strip
                       href     = other_software_url
                     end

                     if !newValue.nil?
                       xml['iris'].requires() {
                         xml['iris'].software() {
                           xml.text(v)
                         }
                       }
                     else
                       xml['iris'].requires() {
                         xml['iris'].software(:href=>href, :newValue=>newValue) {
                           xml.text(v)
                         }
                       }
                     end
                   end
                end

                # processing instrumenttitle
                if !instrumenttitle.nil?
                  xml['iris'].title() {
                    xml.text(instrumenttitle.strip)
                  }
                end

                # processing notes
                if !notes.nil?
                  xml['iris'].notes() {
                    xml.text(notes.strip)
                  }
                end
              }

              ###########################################################################
              # participants
              xml['iris'].participants() {

                # processing participant types
                if !participanttype1.nil?
                  xpath = "/IRIS_Data_Dict/participants/participantTypes//type[@label='"+participanttype1.strip+"']/@value"
                  v = dd_value_from_xpath(xpath)
                  newValue = nil
                  if v.nil?
                    v        = '999'
                    newValue = participanttype1.strip
                  end

                  if !participanttype2.nil?
                    xpath = "/IRIS_Data_Dict/participants/participantTypes//type[@label='"+participanttype2.strip+"']/@value"
                    v2 = dd_value_from_xpath(xpath)
                    if !v2.nil?
                      v = v.to_s + ' ' + v2.to_s
                    end
                  end

                  if newValue.nil?
                    xml['iris'].participantType() {
                      xml.text(v)
                    }
                  else
                    xml['iris'].participantType(:newValue=>newValue) {
                      xml.text(v)
                    }
                  end
                end

                # processing l1
                if !language1.nil? and language1.strip!=''
                  xml['iris'].firstLanguage() {
                    xml.text(language1.strip)
                  }
                end

                # processing l2
                if !language2.nil? and language2.strip!=''
                  xml['iris'].targetLanguage() {
                    xml.text(language2.strip)
                  }
                end
              }

              ###########################################################################
              # relatedItems
              xml['iris'].relatedItems() {
                xml['iris'].relatedItem(:type=>'publication') {
                  # processing publication type
                  if !publication1_type.nil?
                    xpath = "/IRIS_Data_Dict/relatedItems/publicationTypes/type[@label='"+publication1_type.strip+"']/@value"
                    v = dd_value_from_xpath(xpath)
                    xml['iris'].publicationType() {
                      xml.text(publication1_type.strip)
                    }
                  end

                  # processing authors
                  type = 'new'
                  if is_author_in_dd(publication1_author1.strip)
                    type = 'auto'
                  end
                  xml['iris'].author(:type => type) {
                    xml['iris'].fullName  publication1_author1.strip
                    xml['iris'].lastName  publication1_author1.split(',')[0].strip
                    xml['iris'].firstName publication1_author1.split(',')[1].strip
                  }
                  if !publication1_author2.nil? and publication1_author2.to_s.strip!='' and publication1_author2.to_s.strip!='0'
                    type = 'new'
                    if is_author_in_dd(publication1_author2.strip)
                      type = 'auto'
                    end
                    xml['iris'].author(:type => type) {
                      xml['iris'].fullName  publication1_author2.strip
                      xml['iris'].lastName  publication1_author2.split(',')[0].strip
                      xml['iris'].firstName publication1_author2.split(',')[1].strip
                    }
                  end
                  if !publication1_author3.nil?  and publication1_author3.to_s.strip!='' and publication1_author3.to_s.strip!='0'
                    type = 'new'
                    if is_author_in_dd(publication1_author3.strip)
                      type = 'auto'
                    end
                    xml['iris'].author(:type => type) {
                      xml['iris'].fullName  publication1_author3.strip
                      xml['iris'].lastName  publication1_author3.split(',')[0].strip
                      xml['iris'].firstName publication1_author3.split(',')[1].strip
                    }
                  end

                  if !publication1_author4.nil?  and publication1_author4.to_s.strip!='' and publication1_author4.to_s.strip!='0'
                    type = 'new'
                    if is_author_in_dd(publication1_author4.strip)
                      type = 'auto'
                    end
                    xml['iris'].author(:type => type) {
                      xml['iris'].fullName  publication1_author4.strip
                      xml['iris'].lastName  publication1_author4.split(',')[0].strip
                      xml['iris'].firstName publication1_author4.split(',')[1].strip
                    }
                  end

                  if !publication1_author5.nil?  and publication1_author5.to_s.strip!='' and publication1_author5.to_s.strip!='0'
                    type = 'new'
                    if is_author_in_dd(publication1_author5.strip)
                      type = 'auto'
                    end
                    xml['iris'].author(:type => type) {
                      xml['iris'].fullName  publication1_author5.strip
                      xml['iris'].lastName  publication1_author5.split(',')[0].strip
                      xml['iris'].firstName publication1_author5.split(',')[1].strip
                    }
                  end

                  if !publication1_author6.nil? and publication1_author6.to_s.strip!='' and publication1_author6.to_s.strip!='0'
                    type = 'new'
                    if is_author_in_dd(publication1_author6.strip)
                      type = 'auto'
                    end
                    xml['iris'].author(:type => type) {
                      xml['iris'].fullName  publication1_author6.strip
                      xml['iris'].lastName  publication1_author6.split(',')[0].strip
                      xml['iris'].firstName publication1_author6.split(',')[1].strip
                    }
                  end

                  # processing title
                  if !publication1_title.nil?
                    xml['iris'].itemTitle(:type => '') {
                      xml.text publication1_title.strip
                    }
                  end

                  # processing journal
                  if !publication1_journal.nil?
                    xpath = "/IRIS_Data_Dict/relatedItems/journals/journal[@label='"+publication1_journal.strip+"']/@value"
                    v = dd_value_from_xpath(xpath)

                    newValue = nil
                    if v.nil?
                      v = '999'
                      newValue =publication1_journal.strip
                    end

                    if newValue.nil?
                      xml['iris'].journal() {
                        xml.text(v)
                      }
                    else
                      xml['iris'].journal(:newValue=>newValue) {
                        xml.text(v)
                      }
                    end
                  end

                  # processing date
                  if !publication1_date.nil?
                    xml['iris'].yearOfPublication() {
                      xml.text(publication1_date)
                    }
                  end

                  # processing volume
                  if !publication1_volume.nil?
                    xml['iris'].volume() {
                      xml.text(publication1_volume)
                    }
                  end

                  # processing issue no
                  if !publication1_issue_no.nil?
                    xml['iris'].issue() {
                      xml.text(publication1_issue_no)
                    }
                  end

                  # processing page no from
                  if !publication1_page_number_from.nil?
                    xml['iris'].pageFrom() {
                      xml.text(publication1_page_number_from)
                    }
                  end

                  # processing page no to
                  if !publication1_page_number_to.nil?
                    xml['iris'].pageTo() {
                      xml.text(publication1_page_number_to)
                    }
                  end

                  # processing doi
                  if !publication1_doi.nil?
                    xml['iris'].identifier() {
                      xml.text(publication1_doi)
                    }
                  end
                }
              }

              ###########################################################################
              # settings
              xml['iris'].settings() {
                xml['iris'].feedback() {
                  xml.text('1')
                }
                xml['iris'].notifyDownloads() {
                  xml.text('true')
                }
                # processing email
                if !email.nil?
                  xml['iris'].email() {
                    xml.text(email)
                  }
                end
                xml['iris'].comments() {
                }
                xml['iris'].licenceagreement() {
                  xml.text('true')
                }
              }
            }
          end

          iris_metadata << builder.to_xml

        end
      else
        puts 'Seems no data in ' + sheet_name
      end
    end

    iris_metadata

  end

  def ingest(iris)

  end

  def send_via_gmail(user,pass,_to,_subject,_body,attach_file_name)
    gmail = Gmail.connect(user, pass)
    email = gmail.compose do
      to _to
      subject _subject
      body _body
      if !attach_file_name.nil?
        add_file attach_file_name
      end
    end
    email.deliver!
  end
end

bu = BatchUpdater.new()
bu.update()
