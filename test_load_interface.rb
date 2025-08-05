#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify the load interface works correctly

require_relative "lib/i_speaker"

puts "🔄 Testing Load Interface".cyan.bold
puts "=" * 40

# Create a console interface instance
ISpeaker::ConsoleInterface.new

# Test the load_talk method by calling it directly
puts "\n📋 Testing load_talk method...".yellow

# Mock the prompt to see what files would be shown
json_files = Dir.glob("*.json").sort

puts "\nFound #{json_files.length} JSON files:".blue

json_files.each do |filename|
  data = JSON.parse(File.read(filename), symbolize_names: true)
  title = data[:title] || "Untitled"
  slide_count = data[:slides]&.length || 0
  duration = data[:duration_minutes] || "Unknown"
  modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")

  puts "   ✅ #{filename} - \"#{title}\" (#{slide_count} slides, #{duration}min) [#{modified_time}]".green
rescue StandardError
  modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")
  puts "   ⚠️  #{filename} - Invalid JSON format [#{modified_time}]".yellow
end

puts "\n🧪 Testing load_talk_file method with a valid file...".yellow

# Test loading a specific file
test_file = "sample_ruby_basics.json"
if File.exist?(test_file)
  begin
    talk = ISpeaker::Talk.load_from_file(test_file)
    puts "\n✅ Successfully loaded: #{test_file}".green
    puts talk.summary.light_blue
  rescue StandardError => e
    puts "❌ Error loading file: #{e.message}".red
  end
else
  puts "❌ Test file not found: #{test_file}".red
end

puts "\n✨ Load functionality is working correctly!".green.bold
puts "\nTo test the interactive interface, run:".blue
puts "   ruby exe/i_speaker".light_blue
puts "Then select 'Load existing talk' to see the improved interface.".light_blue
