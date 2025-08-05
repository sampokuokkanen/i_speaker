#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test the improved load functionality

require_relative "lib/i_speaker"

puts "🔄 Testing improved load talk functionality".cyan.bold
puts "=" * 50

# First, let's create a few sample talk files to load
puts "\n📝 Creating sample talk files for testing...".yellow

# Create sample talks
talks = [
  {
    filename: "sample_ruby_basics.json",
    title: "Ruby Basics for Beginners",
    description: "An introduction to Ruby programming language fundamentals",
    target_audience: "Programming beginners",
    duration: 20,
    slides: [
      { title: "Welcome to Ruby", content: ["What is Ruby?", "Why learn Ruby?", "Ruby's philosophy"] },
      { title: "Basic Syntax", content: %w[Variables Methods Classes] },
      { title: "Ruby Features", content: ["Dynamic typing", "Object-oriented", "Expressive syntax"] }
    ]
  },
  {
    filename: "sample_advanced_rails.json",
    title: "Advanced Rails Techniques",
    description: "Deep dive into advanced Ruby on Rails patterns and best practices",
    target_audience: "Experienced Rails developers",
    duration: 45,
    slides: [
      { title: "Service Objects", content: ["When to use", "Implementation patterns", "Testing strategies"] },
      { title: "Background Jobs", content: ["Sidekiq basics", "Job patterns", "Error handling"] },
      { title: "API Design", content: ["RESTful patterns", "Serialization", "Authentication"] },
      { title: "Performance", content: ["Database optimization", "Caching strategies", "Monitoring"] }
    ]
  },
  {
    filename: "sample_testing.json",
    title: "Testing Ruby Applications",
    description: "Comprehensive guide to testing Ruby code with various frameworks",
    target_audience: "Ruby developers",
    duration: 30,
    slides: [
      { title: "Testing Fundamentals", content: ["Unit tests", "Integration tests", "Test-driven development"] },
      { title: "RSpec Deep Dive", content: ["Describe blocks", "Let vs instance variables", "Shared examples"] }
    ]
  }
]

# Create the talk files
talks.each do |talk_data|
  talk = ISpeaker::Talk.new(
    title: talk_data[:title],
    description: talk_data[:description],
    target_audience: talk_data[:target_audience],
    duration_minutes: talk_data[:duration]
  )

  talk_data[:slides].each do |slide_data|
    slide = ISpeaker::Slide.new(
      title: slide_data[:title],
      content: slide_data[:content],
      notes: "Speaker notes for #{slide_data[:title]}"
    )
    talk.add_slide(slide)
  end

  talk.save_to_file(talk_data[:filename])
  puts "   ✅ Created: #{talk_data[:filename]}".green
end

# Also create a corrupted JSON file to test error handling
File.write("corrupted_talk.json", "{ invalid json content }")
puts "   ⚠️  Created corrupted file for testing: corrupted_talk.json".yellow

puts "\n📂 Current directory now contains:".blue
Dir.glob("*.json").sort.each do |file|
  size = File.size(file)
  mtime = File.mtime(file).strftime("%Y-%m-%d %H:%M")
  puts "   #{file} (#{size} bytes, modified: #{mtime})"
end

puts "\n🧪 Testing the load functionality...".yellow
puts "The improved load_talk method will now:"
puts "   • Show all JSON files in the current directory"
puts "   • Display talk title, slide count, and duration for each file"
puts "   • Show file modification time"
puts "   • Handle corrupted files gracefully"
puts "   • Allow browsing other directories"
puts "   • Provide manual filename entry as fallback"

puts "\n✨ You can now run 'ruby exe/i_speaker' and select 'Load existing talk'".green
puts "to see the improved interface in action!".green

# Show what the interface would display
puts "\n📋 Preview of what you'll see:".blue
puts "Available talk files:"

Dir.glob("*.json").sort.each do |filename|
  data = JSON.parse(File.read(filename), symbolize_names: true)
  title = data[:title] || "Untitled"
  slide_count = data[:slides]&.length || 0
  duration = data[:duration_minutes] || "Unknown"
  modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")

  puts "   #{filename} - \"#{title}\" (#{slide_count} slides, #{duration}min) [#{modified_time}]".light_blue
rescue StandardError
  modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")
  puts "   #{filename} - ⚠️  Invalid JSON format [#{modified_time}]".yellow
end

puts "\n🎉 Improved load functionality is ready!".green.bold
