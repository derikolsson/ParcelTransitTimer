#!/usr/bin/env ruby
require 'optparse'
require 'csv'

version = "0.7.0-alpha"

# Set command-line variables
options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Parcel Transit Timer "+ version +" by Derik Olsson <do@derik.co>\nUsage: timer.rb [options] output.csv"

  opts.on('-k', '--key STRING', 'Postmaster.io API key') do |x|
    options[:key] = x
  end

  opts.on('--orig FILE', 'Origins File (5ZIPs, one per line)') do |orig|
    options[:orig] = orig
  end
  
  opts.on('--dest FILE', 'Destinations File (5ZIPs, one per line)') do |dest|
    options[:dest] = dest
  end

  opts.on('-b','--b FILE', 'Bypass File (CSV) - Save API calls!') do |byp|
    options[:byp] = byp
  end
  
  opts.on('-o', '--out FILE', 'Output file (CSV)') do |x|
    options[:out] = x
  end

  opts.on('-t', '--test', 'If set, does not make API calls.') do |test|
    options[:test] = test
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

# Parse user entry
begin
  optparse.parse!
  if options[:out].nil? 
    options[:out] = "output.csv"
    unless ARGV[0].nil?
      options[:out] = ARGV[0]
    end
  end
  mandatory = [:orig,:dest,:key]
  missing = mandatory.select{ |param| options[param].nil? }
  if not missing.empty?
    puts "Missing required variables: #{missing.join(', ')}\n\n"
    puts optparse
    exit
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

# Origins to Array
origins = Array.new;
IO.foreach(options[:orig]) do |line|
  origins << line.strip
end
origins = origins.uniq
puts "Origins: " + origins.to_s

# Destinations to Array
dests = Array.new;
IO.foreach(options[:dest]) do |line|
  dests << line.strip
end
dests = dests.uniq
puts "Destinations: " + dests.to_s
exit





filename = options[:csv].to_s
unless filename.include? '.csv'
  filename = filename + ".csv"
end
file = File.new(filename, 'r')
if options[:out].empty?
  name = File.basename(filename, ".csv")
else
  name = File.basename(options[:out].to_s, ".xml")
end
brand = options[:brand].upcase

puts "VTV Project Builder " + version + "\nAuthor: Derik Olsson <derik@derikolsson.com>"
puts "Building FCP project file \"" + name + ".xml\" with " + brand + " graphics..."

myStr = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE xmeml>\n<xmeml version=\"4\">\n";
file.each_line("\n") do |row|
  columns = row.split(",")
  myStr << "<sequence>
  <name>"+columns[0].chomp(".mov")+"</name>
  <clipitem id=\""+brand+"169 \">
  <name>"+brand+"169</name>
</sequence>\n"
end
myStr << "\n</xmeml>"

if options[:out].empty?
  aFile = File.new(name+".xml", "w")
else
  aFile = File.new(options[:out].to_s, "w")
end
aFile.write(myStr)
aFile.close

puts "Finished!"