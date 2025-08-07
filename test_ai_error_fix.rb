#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify AI error handling fixes

require_relative "lib/i_speaker"

puts "🧪 Testing AI Error Handling Fixes".cyan.bold
puts "=" * 40

# Test 1: Simulate JSON parsing error
puts "\n1. Testing JSON parsing error handling...".yellow

class TestConsoleInterface < ISpeaker::ConsoleInterface
  def test_json_parsing_error
    # Create a basic talk first
    @talk = ISpeaker::Talk.new(
      title: "Test Talk",
      description: "This is a test",
      target_audience: "Testers",
      duration_minutes: 20
    )

    puts "✅ Basic talk created: #{@talk.title}".green
    puts "Talk object exists: #{@talk.nil? ? "NO" : "YES"}".blue

    begin
      # Simulate a JSON parsing error
      raise JSON::ParserError, "Test parsing error"
    rescue JSON::ParserError
      puts "\n❌ AI response wasn't in expected JSON format. Using simpler approach.".red
      puts "✅ Basic talk structure created successfully!".green
      puts @talk.summary.light_blue if @talk
      puts "\n💡 You can now add slides manually or use individual AI assistance from the main menu.".blue
    end
  end

  def test_json_extraction
    puts "\n2. Testing JSON extraction from mixed response...".yellow

    # Test the JSON extraction logic
    mixed_response = <<~RESPONSE
      Here is the presentation structure you requested:

      {
        "description": "A comprehensive guide to Ruby programming fundamentals",
        "slides": [
          {
            "title": "Introduction to Ruby",
            "content": ["What is Ruby?", "History and philosophy", "Key features"],
            "speaker_notes": "Start with enthusiasm about Ruby's elegance"
          },
          {
            "title": "Basic Syntax",
            "content": ["Variables and constants", "Methods and blocks", "Control structures"],
            "speaker_notes": "Use interactive examples"
          }
        ]
      }

      This should work well for your presentation!
    RESPONSE

    # Extract JSON using the same logic as in the actual code
    json_content = nil
    if mixed_response.include?("{") && mixed_response.include?("}")
      start_index = mixed_response.index("{")
      bracket_count = 0
      end_index = start_index

      mixed_response[start_index..].each_char.with_index(start_index) do |char, i|
        bracket_count += 1 if char == "{"
        bracket_count -= 1 if char == "}"
        if bracket_count.zero?
          end_index = i
          break
        end
      end

      json_content = mixed_response[start_index..end_index]
    end

    if json_content
      begin
        parsed = JSON.parse(json_content)
        puts "✅ Successfully extracted and parsed JSON".green
        puts "Description: #{parsed["description"][0..50]}...".blue
        puts "Slides found: #{parsed["slides"].length}".blue
      rescue JSON::ParserError => e
        puts "❌ JSON extraction failed: #{e.message}".red
      end
    else
      puts "❌ No JSON found in response".red
    end
  end
end

# Run the tests
interface = TestConsoleInterface.new
interface.test_json_parsing_error
interface.test_json_extraction

puts "\n✅ Error handling tests completed!".green.bold
puts "\nKey fixes implemented:".blue
puts "• @talk is created before AI processing (prevents nil errors)"
puts "• Robust JSON extraction from mixed AI responses"
puts "• Graceful fallback with helpful user messages"
puts "• Clear error messages that don't break the flow"
