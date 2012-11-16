#loading config file for biostudio according with the running environment
PARTSBUILDER_CONFIG = YAML.load_file("#{Rails.root}/config/partsbuilder.yml")[Rails.env]

puts "=> PartsBuilder Config File successfully loaded"
