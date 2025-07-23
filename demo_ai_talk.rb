#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test AI-powered talk creation with Ollama

require_relative 'lib/i_speaker'
require_relative 'config/ruby_llm'

puts "🎤 i_speaker AI Demo with Ollama".cyan
puts "=" * 40

# Test if Ollama is accessible
begin
  response = RubyLLM.chat.ask("Say hello in one word")
  puts "✅ Ollama connection successful!".green
  puts "   Model: #{RubyLLM.configuration.default_model}".light_blue
  puts "   Response: #{response}".light_blue
rescue => e
  puts "❌ Could not connect to Ollama: #{e.message}".red
  puts "   Make sure Ollama is running on localhost:11434".yellow
  exit 1
end

puts "\n" + "=" * 40 + "\n"

# Create a sample talk with AI assistance
puts "Creating a sample talk about Ruby...".yellow

talk = ISpeaker::Talk.new(
  title: "The Joy of Ruby Programming",
  description: "An exploration of what makes Ruby such a delightful language for developers",
  target_audience: "Developers new to Ruby",
  duration_minutes: 20
)

puts talk.summary.light_blue

# Generate some slides with AI
puts "\n🤖 Generating slides with AI...".yellow

slides_to_create = [
  "Introduction - Why Ruby?",
  "Ruby Philosophy and Design Principles",
  "Expressive Syntax Examples",
  "The Ruby Community",
  "Getting Started with Ruby"
]

slides_to_create.each_with_index do |slide_title, index|
  puts "\nCreating slide #{index + 1}: #{slide_title}".green
  
  prompt = ISpeaker::AIPersona.slide_creation_prompt(
    talk.title,
    talk.description,
    index + 1,
    talk.slides.map(&:to_hash)
  )
  
  # Add specific context for this slide
  prompt += "\n\nCreate a slide specifically about: #{slide_title}"
  prompt += "\nProvide 3-4 key bullet points and speaker notes."
  prompt += "\nFormat the response as JSON with 'title', 'content' (array), and 'speaker_notes'."
  
  begin
    response = RubyLLM.chat.ask(prompt)
    
    # Try to parse JSON from response
    require 'json'
    json_match = response.match(/\{.*\}/m)
    if json_match
      slide_data = JSON.parse(json_match[0])
      slide = ISpeaker::Slide.new(
        title: slide_data["title"] || slide_title,
        content: slide_data["content"] || ["Content point 1", "Content point 2", "Content point 3"],
        notes: slide_data["speaker_notes"] || "Speaker notes for this slide"
      )
      talk.add_slide(slide)
      puts "   ✅ Added: #{slide.title}".green
      slide.content.each { |point| puts "      • #{point}".light_blue }
    else
      # Fallback if JSON parsing fails
      slide = ISpeaker::Slide.new(
        title: slide_title,
        content: [
          "Key point about #{slide_title}",
          "Another important aspect",
          "Something to remember"
        ],
        notes: "Explain #{slide_title} in detail"
      )
      talk.add_slide(slide)
      puts "   ⚠️  Added with default content".yellow
    end
  rescue => e
    puts "   ❌ Error: #{e.message}".red
  end
end

# Display the complete talk
puts "\n" + "=" * 40
puts "\n📊 Complete Talk Structure:".cyan.bold
puts talk.summary

# Export to different formats
puts "\n📁 Exporting talk...".yellow

# Export as JSON
talk.save_to_file("demo_ai_talk.json")
puts "   ✅ Saved as JSON: demo_ai_talk.json".green

# Export as Slidev
interface = ISpeaker::ConsoleInterface.new
interface.instance_variable_set(:@talk, talk)
interface.send(:export_slidev, "demo_ai_talk_slidev.md")
puts "   ✅ Saved as Slidev: demo_ai_talk_slidev.md".green

# Export as regular markdown
interface.send(:export_markdown, "demo_ai_talk.md")
puts "   ✅ Saved as Markdown: demo_ai_talk.md".green

puts "\n🎉 Demo complete!".green.bold
puts "You can now:"
puts "  • View the generated talk in demo_ai_talk.json"
puts "  • Open demo_ai_talk_slidev.md with Slidev"
puts "  • Read demo_ai_talk.md for a simple markdown version"