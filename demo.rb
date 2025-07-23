# frozen_string_literal: true

# Example of using i_speaker programmatically
require_relative "lib/i_speaker"

# Create a new talk
talk = ISpeaker::Talk.new(
  title: "Introduction to i_speaker",
  description: "Learn how to create presentations with AI assistance",
  target_audience: "Ruby developers",
  duration_minutes: 20,
)

# Add slides
intro_slide = talk.add_slide
intro_slide.title = "Welcome to i_speaker"
intro_slide.add_content("AI-powered presentation creation")
intro_slide.add_content("Step-by-step slide building")
intro_slide.add_content("Multiple export formats")
intro_slide.notes = "Start with energy and enthusiasm"

features_slide = talk.add_slide
features_slide.title = "Key Features"
features_slide.add_content("Interactive console interface")
features_slide.add_content("AI assistance for content generation")
features_slide.add_content("Sample talk templates")
features_slide.add_content("Easy editing and rewriting")

demo_slide = talk.add_slide
demo_slide.title = "Live Demo"
demo_slide.add_content("Create a new talk from scratch")
demo_slide.add_content("Get AI suggestions")
demo_slide.add_content("Export in multiple formats")
demo_slide.notes = "Show the actual console interface"

# Display the talk summary
puts talk.summary

# Save the talk
talk.save_to_file("demo_talk.json")
puts "\nTalk saved as demo_talk.json"

# Show how to explore sample talks
puts "\nSample talks available:"
ISpeaker::SampleTalks.all.each_with_index do |sample, index|
  puts "#{index + 1}. #{sample[:title]}"
  puts "   #{sample[:description]}"
  puts "   #{sample[:slides].length} slides"
  puts
end
