#!/usr/bin/env ruby
require 'optparse'
require 'csv'
require 'rubygems'
require 'typhoeus'
require 'json'

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

  options[:carr] = "ups"
  opts.on('-c', '--carrier STRING', 'Which carrier? (fedex,ups,usps - default: ups)') do |carr|
    validCarriers = ["fedex","ups","usps"]
    if(validCarriers.include?(carr.downcase))
      options[:carr] = carr
    else
      puts "Invalid carrier: " + carr.downcase + "\nValid Options: #{validCarriers.join(', ')}"
      exit
    end
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

# Bypass shit will go here, later

# String to Integer function - Credit to Niklas B. on StackOverflow: http://stackoverflow.com/a/10332716
def try_to_i(str, default = nil)
  str =~ /^-?\d+$/ ? str.to_i : default
end

# Obtain Data
hydra = Typhoeus::Hydra.new
times = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
dow_today = try_to_i((Time.now).strftime("%u"))
dests.each do |dest|
  origins.each do |orig|
    req = Typhoeus::Request.new("https://api.postmaster.io/v1/times",
      :body => {
        :from_zip => orig,
        :to_zip => dest,
        :weight => 1.0,
        :carrier => options[:carr],
        :commercial => TRUE
      },
      :method => :post,
      :userpwd => options[:key])
    req.on_complete do |res|
      dtime = 0
      out = JSON.parse(res.body)
      out["services"].each do |svc|
        if(svc["service"]=="GROUND")
          dtime = svc["delivery_timestamp"]
        end
      end
      puts "\n" + orig + "-" + dest + ": " + Time.at(dtime).strftime("%u") + " " + Time.at(dtime).to_s
      dow_fin = try_to_i(Time.at(dtime).strftime("%u"))
      if(dow_fin > 5)
        dow_fin = 1
      end
      tt = dow_fin-dow_today
      if(tt<1)
        tt = tt + 5
      end
      times[dest][orig] = tt
    end
    hydra.queue(req)
  end
end
hydra.run # Hold onto your pants!

# File string preparation
myStr = "dest,"+origins.join(",")
dests.each do |dest|
  myStr = myStr + "\n" + dest + ","
  origins.each do |orig|
    myStr = myStr + times[dest][orig].to_s + ","
  end
  myStr = myStr.chomp(",")
end

# Write to file
outFile = File.new(options[:out].to_s,"w")
outFile.write(myStr)
outFile.close