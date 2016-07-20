1. checkaudiocustomlabel

   DESC: Check if the sounditem object track title has been incorrectly put in the RELS-INT and if it is, move it to dc:title
   
   NB: This scripts is tested against Ruby 2.2 / Fedora 3.6.2

   rename pids.properties.DEMO to pids.properties and update PIDs list

   rename system.yaml.DEMO to system.yaml and update server credentials

   Make sure faraday and nokogiri have been installed before running the script

   To run: ruby check_custom_labe.rb

2. irisdump

   DESC: get iris data dump from solr / fedora for further processing in R package, as required by project partners
   
   Do similar thing for pids.properties and system.yaml as described in 1)

   Make sure faraday, nokogiri, and rubyzip are installed before running the script
 
   To run: ruby iris_dump.rb

3. checkapprovedinstypes
  
   DESC: check if there are any IRIS objects that
   
   * has new instrument type being approved but
   
   * the primary instrument type attribute has not been updated

   It requires the gem: colorize, so needs to run:

   gem install colorize

   To run: ruby check_approved_instype.rb


   

