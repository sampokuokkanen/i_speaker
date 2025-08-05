#!/usr/bin/env ruby
# frozen_string_literal: true

# Showcase script demonstrating the improved load interface

require_relative "lib/i_speaker"

puts "🎯 i_speaker Load Interface Showcase".cyan.bold
puts "=" * 50

puts "\n📝 Here's what the improved load interface looks like:".blue
puts

# Show current directory contents
json_files = Dir.glob("*.json").sort

if json_files.empty?
  puts "📁 No talk files found in current directory.".yellow
  puts "   Create a new talk or make sure you're in the right directory.".light_blue
else
  puts "📁 Available talk files:".blue
  puts

  json_files.each_with_index do |filename, index|
    data = JSON.parse(File.read(filename), symbolize_names: true)
    title = data[:title] || "Untitled"
    slide_count = data[:slides]&.length || 0
    duration = data[:duration_minutes] || "Unknown"
    modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")

    puts "#{index + 1}. #{filename} - \"#{title}\" (#{slide_count} slides, #{duration}min) [#{modified_time}]".light_blue
  rescue StandardError
    modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")
    puts "#{index + 1}. #{filename} - ⚠️  Invalid JSON format [#{modified_time}]".yellow
  end

  puts "#{json_files.length + 1}. 📝 Enter filename manually".cyan
  puts "#{json_files.length + 2}. 📂 Browse other directories".cyan
  puts "#{json_files.length + 3}. 🔙 Back to main menu".cyan
end

puts "\n✨ Key Improvements:".green.bold
puts "   • 📊 Shows talk title, slide count, and duration at a glance"
puts "   • 📅 Displays file modification time for easy identification"
puts "   • ⚠️  Gracefully handles corrupted JSON files"
puts "   • 📂 Allows browsing other directories"
puts "   • 📝 Fallback to manual filename entry"
puts "   • 🔄 Automatically refreshes when you return to the menu"

puts "\n🎮 To experience the interactive interface:".blue
puts "   1. Run: ruby exe/i_speaker"
puts "   2. Select: 'Load existing talk'"
puts "   3. Choose from the nicely formatted list!"

puts "\n📖 Example usage scenarios:".cyan
puts "   • Working on multiple talks and need to quickly identify them"
puts "   • Resuming work on a presentation from days ago"
puts "   • Loading talks from different project folders"
puts "   • Collaborating with others and loading their talk files"

puts "\n🔗 This enhanced interface makes i_speaker much more user-friendly!".green.bold
