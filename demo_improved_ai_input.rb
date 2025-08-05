#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test improved AI input gathering

require_relative "lib/i_speaker"

puts "🤖 Testing Improved AI Input Gathering".cyan.bold
puts "=" * 50

puts "\nThis demo shows how the AI now gets both title AND description".blue
puts "for better context and more relevant content generation.\n".light_blue

# Simulate the improved input flow
class TestAIInput
  def initialize
    @prompt = TTY::Prompt.new
  end

  def simulate_improved_input
    puts "🎯 Simulating the improved AI-guided talk creation...".yellow

    # Title input (unchanged)
    puts "\n1. Title Input:".bold
    title = "Building Resilient Ruby Applications"
    puts "   Title: #{title}".light_blue

    # New: Detailed description input
    puts "\n2. Detailed Description Input (NEW):".bold
    description = "A comprehensive guide to building Ruby applications that can handle failures gracefully, recover from errors, and maintain high availability in production environments. We'll cover error handling patterns, monitoring strategies, and architectural decisions."
    puts "   Description: #{description}".light_blue

    # Additional context (optional)
    puts "\n3. Additional Context (Optional):".bold
    additional_context = "Focus on practical examples from real production systems. Include specific tools like Sidekiq, Redis, and monitoring solutions."
    puts "   Additional: #{additional_context}".light_blue

    # Show how this gets combined for AI
    puts "\n📝 Combined Context for AI:".blue
    full_context = description
    full_context += "\n\nAdditional context: #{additional_context}" unless additional_context.strip.empty?
    puts full_context.light_blue

    [title, description, additional_context, full_context]
  end

  def demonstrate_ai_prompt_improvement(title, description, additional_context)
    audience = "Senior Ruby developers"
    duration = 35

    puts "\n🧠 AI Prompt Comparison:".cyan.bold

    # Old style (title only)
    puts "\n❌ OLD PROMPT (title only):".red
    old_prompt = <<~PROMPT
      You're helping create a presentation titled "#{title}".
      Audience: #{audience}
      Duration: #{duration} minutes

      Generate 3-5 clarifying questions...
    PROMPT
    puts old_prompt.light_red

    # New style (title + description + context)
    puts "\n✅ NEW PROMPT (title + description + context):".green
    new_prompt = <<~PROMPT
      You're helping create a presentation titled "#{title}".
      Description: #{description}
      #{"Additional context: #{additional_context}" unless additional_context.strip.empty?}
      Audience: #{audience}
      Duration: #{duration} minutes

      Generate 3-5 clarifying questions...
    PROMPT
    puts new_prompt.light_green

    puts "\n💡 Benefits of the new approach:".blue
    puts "   • AI understands the talk's purpose and goals"
    puts "   • More relevant and specific questions"
    puts "   • Better slide suggestions based on full context"
    puts "   • Consistent with manual talk creation flow"
    puts "   • Reduces need for follow-up clarifications"
  end

  def show_expected_improvements
    puts "\n🎯 Expected AI Improvements:".cyan.bold

    puts "\nWith title only:".red
    puts "   - Generic questions about presentation structure"
    puts "   - Basic slide suggestions"
    puts "   - May miss key topics or focus areas"

    puts "\nWith title + description + context:".green
    puts "   - Specific questions about resilience patterns"
    puts "   - Targeted slide suggestions (error handling, monitoring)"
    puts "   - Questions about production examples and tools"
    puts "   - Better understanding of technical depth needed"

    puts "\n📊 Example Question Improvement:".blue
    puts "\n❌ Generic question:".red
    puts '   "What are the main topics you want to cover?"'

    puts "\n✅ Specific question:".green
    puts '   "What specific failure scenarios have you encountered in production Ruby applications?"'
    puts '   "Which monitoring tools would you like to demonstrate in the talk?"'
  end
end

# Run the demonstration
demo = TestAIInput.new
title, description, additional_context, = demo.simulate_improved_input

demo.demonstrate_ai_prompt_improvement(title, description, additional_context)
demo.show_expected_improvements

puts "\n🧪 Testing with Actual AI (if available):".cyan.bold

# Test with actual AI if available
begin
  interface = ISpeaker::ConsoleInterface.new

  if interface.instance_variable_get(:@ai_available)
    puts "✅ AI is available - testing improved prompts...".green

    # Create a sample prompt with the new format
    test_prompt = <<~PROMPT
      You're helping create a presentation titled "#{title}".
      Description: #{description}
      Additional context: #{additional_context}
      Audience: Senior Ruby developers
      Duration: 35 minutes

      Generate 3 specific clarifying questions that would help create a better, more focused presentation.
      Questions should be specific and help understand:
      - Key technical details about resilience patterns
      - Specific production scenarios to cover
      - Preferred tools and technologies to demonstrate

      Format as numbered questions, one per line.
    PROMPT

    puts "\n🤖 AI Response to improved prompt:".blue
    response = interface.send(:ai_ask, test_prompt)
    puts response.light_blue

  else
    puts "⚠️  AI not available for live testing".yellow
  end
rescue StandardError => e
  puts "❌ Error testing with AI: #{e.message}".red
end

puts "\n🎉 Improved AI Input Summary:".green.bold
puts "✅ AI now receives detailed talk description"
puts "✅ Optional additional context for specific requirements"
puts "✅ More relevant and specific AI questions"
puts "✅ Better slide content suggestions"
puts "✅ Consistent with manual talk creation workflow"
