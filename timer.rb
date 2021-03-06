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

  opts.on('-b','--bypass FILE', 'Bypass File (CSV) - Save API calls!') do |byp|
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

  # Verbose Option will go here, someday

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

load "states.rb"

# Origins to Array
origins = Array.new;
text=File.open(options[:orig]).read
text.gsub!(/\r\n?/, "\n")
text.each_line do |line|
  origins << line.strip
end
origins = origins.uniq

# Destinations to Array
dests = Array.new;

text=File.open(options[:dest]).read
text.gsub!(/\r\n?/, "\n")
text.each_line do |line|
  dests << line.strip
end
dests = dests.uniq

# Bypass shit will go here, later
if options[:byp]
  bypass = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  CSV.foreach(options[:byp], :headers => true) do |row|
    bypass[row["zip"]][row["state"]] = row["days"]
  end
end

# String to Integer function - Credit to Niklas B. on StackOverflow: http://stackoverflow.com/a/10332716
def try_to_i(str, default = nil)
  str =~ /^-?\d+$/ ? str.to_i : default
end

i = 0

# Obtain Data
hydra = Typhoeus::Hydra.new(max_concurrency: 10)
times = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
apiCalls = 0
dow_today = try_to_i((Time.now).strftime("%u"))
dests.each do |dest|
  origins.each do |orig|
    i = i + 1
    switch = 0
    if bypass
      if bypass.has_key?(orig)
        dstate = @statezips[dest[0,3]]
        unless bypass[orig][dstate.upcase].empty?
          times[dest][orig] = bypass[orig][dstate.upcase]
          unless options[:test]
            puts orig.to_s + "->" + dest.to_s + " MATCHED! " + bypass[orig][dstate.upcase].to_s + " day(s)"
          end
        else
          switch = switch + 1
        end
      else
        switch = switch + 1
      end
    else
      switch = switch + 1
    end
    if switch > 0
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
        if res.success?
          dtime = 0
          out = JSON.parse(res.body)
          unless out.has_key?("services")
            puts "ERROR: \n" + out.to_s
          end
          out["services"].each do |svc|
            if(svc["service"]=="GROUND")
              dtime = svc["delivery_timestamp"]
            end
          end
          dow_fin = try_to_i(Time.at(dtime).strftime("%u"))
          if(dow_fin > 5)
            dow_fin = 1
          end
          tt = dow_fin-dow_today
          if(tt<1)
            tt = tt + 5
          end
          times[dest][orig] = tt
          puts orig.to_s + "->" + dest.to_s + " in "+tt.to_s+" business day(s)"
        elsif res.timed_out?
          puts orig.to_s + "->" + dest.to_s + " - Timed out"
        elsif res.code == 0
          puts orig.to_s + "->" + dest.to_s + " - ERROR: Could not get an HTTP response"
        else
          puts orig.to_s + "->" + dest.to_s + " - HTTP Request Failed: " + res.code.to_s
        end
      end
      unless options[:test]
        hydra.queue(req)
      end
      apiCalls = apiCalls + 1
    end
  end
end
unless options[:test]
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

  puts "Success! Transit times written to "+options[:out]+"\n"
end
puts "API Calls: "+apiCalls.to_s
exit