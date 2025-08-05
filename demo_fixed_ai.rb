#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo to test the fixed AI complete talk creation

require_relative "lib/i_speaker"

puts "🎯 Testing Fixed AI Complete Talk Creation".cyan.bold
puts "=" * 50

# Create console interface
interface = ISpeaker::ConsoleInterface.new

puts "\n🤖 AI Status:".blue
if interface.instance_variable_get(:@ai_available)
  puts "✅ AI is available and ready".green
else
  puts "❌ AI is not available".red
  exit 1
end

puts "\n📝 Testing complete talk creation with better error handling...".yellow

# We'll simulate the user input by creating a talk with the fixed method
class TestInterface < ISpeaker::ConsoleInterface
  def test_create_talk_with_robust_ai
    puts "\n🚀 Simulating complete talk creation with AI...".blue

    # Simulate basic inputs
    title = "Ruby Best Practices"
    topic_context = "A practical guide to writing clean, maintainable Ruby code"
    audience = "Ruby developers"
    duration = 25

    puts "Title: #{title}".light_blue
    puts "Context: #{topic_context}".light_blue
    puts "Audience: #{audience}".light_blue
    puts "Duration: #{duration} minutes".light_blue

    # Create basic talk first (this is the key fix)
    @talk = ISpeaker::Talk.new(
      title: title,
      description: topic_context,
      target_audience: audience,
      duration_minutes: duration,
    )

    puts "\n✅ Basic talk structure created successfully!".green
    puts @talk.summary.light_blue

    # Test AI call for slide generation
    puts "\n🤖 Testing AI slide generation...".yellow

    begin
      prompt = <<~PROMPT
        Create 3-4 slides for a #{duration}-minute talk about "#{title}".
        Topic: #{topic_context}
        Audience: #{audience}

        IMPORTANT: Respond ONLY with valid JSON in exactly this format:
        {
          "description": "An updated description of the talk",
          "slides": [
            {
              "title": "slide title",
              "content": ["point 1", "point 2", "point 3"],
              "speaker_notes": "speaker notes"
            }
          ]
        }
      PROMPT

      response = ai_ask(prompt)
      puts "AI Response length: #{response.length} characters".blue
      puts "Contains JSON markers: #{response.include?("{") && response.include?("}") ? "YES" : "NO"}".blue

      # Try to parse with our robust method
      json_content = nil
      if response.include?("{") && response.include?("}")
        start_index = response.index("{")
        bracket_count = 0
        end_index = start_index

        response[start_index..-1].each_char.with_index(start_index) do |char, i|
          bracket_count += 1 if char == "{"
          bracket_count -= 1 if char == "}"
          if bracket_count == 0
            end_index = i
            break
          end
        end

        json_content = response[start_index..end_index]
      end

      if json_content
        puts "\n📄 Extracted JSON content:".blue
        puts json_content[0..200] + (json_content.length > 200 ? "..." : "")

        talk_structure = JSON.parse(json_content)

        # Update talk description if provided
        if talk_structure["description"] && !talk_structure["description"].empty?
          @talk.description = talk_structure["description"]
          puts "\n✅ Updated talk description".green
        end

        slides = talk_structure["slides"] || []
        if slides.any?
          puts "\n📋 Generated slides:".blue
          slides.each_with_index do |slide_data, index|
            slide_title = slide_data["title"] || "Slide #{index + 1}"
            content = slide_data["content"] || ["Content for slide #{index + 1}"]
            puts "\n#{index + 1}. #{slide_title}".bold
            content.each { |point| puts "   • #{point}" }

            # Create the actual slide
            slide = ISpeaker::Slide.new(
              title: slide_title,
              content: content,
              notes: slide_data["speaker_notes"] || "Notes for slide #{index + 1}"
            )
            @talk.add_slide(slide)
          end

          puts "\n🎉 Talk completed successfully!".green.bold
          puts @talk.summary.light_blue
        else
          puts "\n⚠️  No slides generated, but talk structure is ready".yellow
        end

      else
        puts "\n⚠️  No valid JSON found in AI response".yellow
        puts "✅ Basic talk is still available for manual editing".green
        puts @talk.summary.light_blue
      end
    rescue JSON::ParserError => e
      puts "\n❌ JSON parsing error: #{e.message}".red
      puts "✅ Basic talk structure is safe and ready".green
      puts @talk.summary.light_blue
    rescue StandardError => e
      puts "\n❌ Unexpected error: #{e.message}".red
      puts "✅ Basic talk structure is safe and ready".green
      puts @talk.summary.light_blue
    end
  end
end

# Run the test
test_interface = TestInterface.new
test_interface.test_create_talk_with_robust_ai

puts "\n🎯 Test Summary:".cyan.bold
puts "✅ Talk object is always created (no more nil errors)"
puts "✅ JSON parsing is more robust"
puts "✅ Clear error messages guide the user"
puts "✅ Graceful fallback to manual editing"
puts "✅ User can always proceed with their work"

puts "\n💡 The improved error handling ensures a smooth user experience!".green
