crash_file = ARGV[0]
dsym_file = ARGV[1]
quiet = !ARGV[2].nil? && ARGV[2] == "-q"

if (crash_file.nil? || dsym_file.nil?)
  puts "Usage: ruby symbolicate.rb <crash_file> <dsym_file>"
  exit false
end

if (dsym_file =~ /\.dsym\/?/i)
  Dir.entries(dsym_file+"/Contents/Resources/DWARF/").each {
    |entry|
    next if entry.start_with?(".")
    dsym_file = dsym_file+"/Contents/Resources/DWARF/"+entry
    break
  }
end

crash_content = ""
File.open(crash_file, "r") {
  |f| crash_content = f.read
}

process_name = crash_content.scan(/^Process:\s+(.*?)\s\[/im).flatten.first
load_address, bundle_identifier = crash_content.scan(/Binary Images:.*?(0x.*?)\s.*?\+(.*?)\s\(/im).flatten
addresses = crash_content.scan(/^\d+\s+(?:#{bundle_identifier}|#{process_name}).*?(0x.*?)\s/im).flatten
code_type = crash_content.scan(/^Code Type:(.*?)(?:\(.*\))?$/i).flatten.first.strip

code_types_to_arch = {'X86-64' => 'x86_64', 'X86' => 'i386', 'PPC' => 'ppc'}
arch = code_types_to_arch[code_type] || code_type

if (!quiet)
  puts "Process: #{process_name}"
  puts "Bundle Identifier: #{bundle_identifier}"
  puts "Load address: #{load_address}"
end

result = `xcrun atos -o \"#{dsym_file}\" -arch #{arch} -l #{load_address} #{addresses.join(" ")}`.strip

if (!result.empty?)
  lines = result.split("\n")

  if lines.count != addresses.count
    puts "Unexpected error."
    puts lines
    exit false
  else
    addresses.each_index {
      |index|
      symbol = lines[index]
      crash_content.gsub!(/#{addresses[index]}.*?$/i, "#{addresses[index]} #{symbol}")
    }

    puts crash_content

    exit true
  end
else
  puts "Couldn't continue because of atos error."
  exit false
end
