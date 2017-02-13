require 'yaml'

class PropertiesManager
  def initialize(file)
    @file = file
  end

  def getPropertiesHash()
    node = YAML::load(File.open(@file))
    #puts node
    #puts node.class

    properties = Hash.new

    node.split(' ').each do |item|
      k = item.split("=").first
      v = item.split("=").last
      properties[k] = v
    end
    properties
  end
end
