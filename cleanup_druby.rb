#!/usr/bin/env ruby
# Simple script to clean up stale i_speaker and DRuby processes

puts "🧹 Cleaning up stale i_speaker processes..."

# Find i_speaker processes
processes = `ps aux | grep -E "i_speaker" | grep -v grep`.split("\n")

if processes.empty?
  puts "✅ No i_speaker processes found"
else
  puts "Found #{processes.length} i_speaker processes:"
  processes.each { |p| puts "  #{p}" }
  
  # Extract PIDs
  pids = processes.map { |p| p.split[1] }.compact
  
  if pids.any?
    print "Kill these processes? (y/N): "
    response = gets.chomp.downcase
    
    if response == 'y' || response == 'yes'
      pids.each do |pid|
        begin
          Process.kill('TERM', pid.to_i)
          puts "✅ Killed process #{pid}"
        rescue => e
          puts "⚠️ Could not kill process #{pid}: #{e.message}"
        end
      end
    else
      puts "Skipped cleanup"
    end
  end
end

# Check for processes using port 9000
puts "\n🔍 Checking port 9000..."
port_usage = `lsof -i :9000 2>/dev/null`
if port_usage.empty?
  puts "✅ Port 9000 is free"
else
  puts "⚠️ Port 9000 is in use:"
  puts port_usage
end

puts "\n🎯 Use this script before starting i_speaker to avoid conflicts"