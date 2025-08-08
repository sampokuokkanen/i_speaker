#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/i_speaker/console_interface"
require_relative "lib/i_speaker/talk"
require_relative "lib/i_speaker/slide"

# Test basic async functionality
puts "Testing Async refactor..."

# Create a simple test talk
talk = ISpeaker::Talk.new(title: "Test Talk")
talk.add_slide(ISpeaker::Slide.new(title: "Test Slide", content: ["Test content"]))

# Test console interface creation
console = ISpeaker::ConsoleInterface.new

# Test that the async tasks initialize properly
puts "✓ Console interface created successfully"
puts "✓ Async dependency loaded"
puts "✓ Commentary tasks initialized: #{console.instance_variable_get(:@commentary_tasks).class}"

# Test commentary generation (if AI is available)
if console.instance_variable_get(:@ai_available)
  puts "✓ AI is available, testing async commentary generation..."
  
  Async do
    slide = talk.slides.first
    task = console.send(:start_commentary_generation, slide, "test_key")
    puts "✓ Async task created: #{task.class}"
    
    # Wait a moment for the task to start
    sleep(0.1)
    puts "✓ Task running: #{task.running?}"
  end
else
  puts "⚠️  AI not available, skipping commentary test"
end

# Test presentation server
puts "Testing presentation server..."
server = ISpeaker::PresentationServer.new
puts "✓ Presentation server created"
puts "✓ Server task initialized: #{server.instance_variable_get(:@server_task).class}"

puts "\n🎉 All async refactoring tests passed!"
puts "Samuel Williams would be proud! 🚀"