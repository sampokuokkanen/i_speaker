#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script showing the complete i_speaker workflow with Ollama AI integration

require_relative "lib/i_speaker"

puts "🎤 i_speaker Complete Workflow Demo".cyan.bold
puts "=" * 50

# Initialize the console interface (it will auto-detect Ollama)
interface = ISpeaker::ConsoleInterface.new

# Simulate creating a talk with AI assistance using direct method calls
puts "\n🤖 Creating a demo talk with AI assistance...".yellow

# Create a talk manually for demo purposes
title = "Building AI-Powered Ruby Applications"
description = "Learn how to integrate AI capabilities into your Ruby applications using local models"
audience = "Ruby developers"
duration = 25

talk = ISpeaker::Talk.new(
  title: title,
  description: description,
  target_audience: audience,
  duration_minutes: duration
)

puts "\n📋 Talk Created:".blue
puts talk.summary.light_blue

# Test AI integration by creating some slides
if interface.instance_variable_get(:@ai_available)
  puts "\n🤖 Using AI to create slides...".yellow

  slide_topics = [
    "Introduction to AI in Ruby Applications",
    "Setting up Ollama for Local AI",
    "Creating Simple Chat Interfaces",
    "Building AI-Powered Tools",
    "Best Practices and Security Considerations"
  ]

  slide_topics.each_with_index do |topic, index|
    puts "\nCreating slide #{index + 1}: #{topic}".green

    begin
      prompt = "Create content for a slide titled '#{topic}' in a talk about '#{title}'.
      Target audience: #{audience}
      Provide 3-4 key bullet points that cover the essential information.
      Keep it practical and focused on Ruby development.

      Respond with just the bullet points, one per line, starting with '- '."

      ai_response = interface.send(:ai_ask, prompt)

      if ai_response
        # Parse the response to extract bullet points
        content = ai_response.split("\n")
                             .select { |line| line.strip.start_with?("-") }
                             .map { |line| line.strip.sub(/^-\s*/, "") }
                             .reject(&:empty?)

        # Fallback content if AI doesn't provide proper format
        if content.empty?
          content = [
            "Key concept about #{topic.downcase}",
            "Practical implementation details",
            "Common challenges and solutions"
          ]
        end

        slide = ISpeaker::Slide.new(
          title: topic,
          content: content,
          notes: "Explain #{topic.downcase} with practical examples and encourage audience questions."
        )

        talk.add_slide(slide)
        puts "   ✅ Added slide: #{slide.title}".green
        content.each { |point| puts "      • #{point}".light_blue }
      end
    rescue StandardError => e
      puts "   ⚠️  AI error: #{e.message}".yellow
      # Add a basic slide as fallback
      slide = ISpeaker::Slide.new(
        title: topic,
        content: ["Overview of #{topic.downcase}", "Key implementation details", "Best practices"],
        notes: "Cover the basics of #{topic.downcase}"
      )
      talk.add_slide(slide)
      puts "   ✅ Added basic slide: #{slide.title}".green
    end
  end
else
  puts "\n⚠️  AI not available, creating basic slides...".yellow

  # Create basic slides without AI
  slide_topics = [
    "Introduction to AI in Ruby Applications",
    "Local AI with Ollama",
    "Implementation Examples",
    "Best Practices"
  ]

  slide_topics.each do |topic|
    slide = ISpeaker::Slide.new(
      title: topic,
      content: ["Key point about #{topic.downcase}", "Implementation details", "Best practices"],
      notes: "Explain #{topic.downcase} in detail"
    )
    talk.add_slide(slide)
    puts "   ✅ Added slide: #{topic}".green
  end
end

# Display the complete talk
puts "\n#{"=" * 50}"
puts "\n📊 Complete Talk Structure:".cyan.bold
puts talk.summary

# Test all export formats
puts "\n📁 Exporting talk in different formats...".yellow

# Save as JSON
talk.save_to_file("demo_complete_talk.json")
puts "   ✅ JSON: demo_complete_talk.json".green

# Set the talk in interface for export methods
interface.instance_variable_set(:@talk, talk)

# Export as regular markdown
interface.send(:export_markdown, "demo_complete_talk.md")
puts "   ✅ Markdown: demo_complete_talk.md".green

# Export as Slidev presentation
interface.send(:export_slidev, "demo_complete_slides.md")
puts "   ✅ Slidev: demo_complete_slides.md".green

# Export as text
interface.send(:export_text, "demo_complete_talk.txt")
puts "   ✅ Text: demo_complete_talk.txt".green

puts "\n🎉 Demo Complete!".green.bold
puts "\nGenerated files:".blue
puts "  • demo_complete_talk.json - Full talk data"
puts "  • demo_complete_talk.md - Markdown format"
puts "  • demo_complete_slides.md - Slidev presentation (ready to run!)"
puts "  • demo_complete_talk.txt - Plain text format"

puts "\n💡 To use the Slidev presentation:".cyan
puts "  1. Install Slidev: npm install -g @slidev/cli"
puts "  2. Run: slidev demo_complete_slides.md"
puts "  3. Open http://localhost:3030"

if interface.instance_variable_get(:@ai_available)
  puts "\n✨ AI-powered features demonstrated:".green
  puts "  • Automatic slide content generation"
  puts "  • Context-aware suggestions"
  puts "  • Local AI processing with Ollama"
else
  puts "\n💡 To enable AI features:".yellow
  puts "  • Start Ollama: ollama serve"
  puts "  • Pull a model: ollama pull llama3.2"
  puts "  • Or configure RubyLLM with API keys"
end
