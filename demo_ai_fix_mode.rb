#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to showcase AI Fix Mode capabilities

require_relative 'lib/i_speaker'

puts "🔧 AI Fix Mode Demo - Expanding Presentations".cyan.bold
puts "=" * 50

puts "\n📋 Demo Overview:".yellow
puts "This demo shows how AI Fix Mode helps create comprehensive presentations"
puts "with appropriate slide counts for longer talks (30+ minutes)."
puts "\nKey features:".blue
puts "• Calculate recommended slide counts based on duration"
puts "• Add slides at specific positions"
puts "• Expand sections with more detail"
puts "• Fill gaps between slides"
puts "• Generate complete slide sets"

# Create a sample talk with just a few slides
puts "\n🎯 Creating a sample 30-minute talk with only 7 slides...".yellow

talk = ISpeaker::Talk.new(
  title: "Advanced Ruby Performance Optimization",
  description: "A comprehensive guide to optimizing Ruby applications for speed and efficiency, covering profiling, memory management, and advanced techniques.",
  target_audience: "Senior Ruby developers",
  duration_minutes: 30
)

# Add initial slides (simulating what AI typically creates)
initial_slides = [
  { title: "Introduction to Ruby Performance", content: ["Why performance matters", "Common misconceptions", "Goals for today"] },
  { title: "Profiling Tools", content: ["ruby-prof", "stackprof", "memory_profiler"] },
  { title: "Memory Management", content: ["GC tuning", "Object allocation", "Memory leaks"] },
  { title: "Algorithm Optimization", content: ["Big O notation", "Data structure choices", "Benchmarking"] },
  { title: "Database Performance", content: ["N+1 queries", "Eager loading", "Query optimization"] },
  { title: "Caching Strategies", content: ["Rails caching", "Redis", "CDN integration"] },
  { title: "Conclusion", content: ["Key takeaways", "Resources", "Q&A"] }
]

initial_slides.each do |slide_data|
  slide = ISpeaker::Slide.new(
    title: slide_data[:title],
    content: slide_data[:content],
    notes: "Speaker notes for #{slide_data[:title]}"
  )
  talk.add_slide(slide)
end

puts "✅ Created talk: \"#{talk.title}\"".green
puts "   Duration: #{talk.duration_minutes} minutes".light_blue
puts "   Current slides: #{talk.slides.length}".light_blue

# Show the issue
puts "\n⚠️  Problem:".red
puts "   For a 30-minute talk, we only have 7 slides!"
puts "   This means ~4.3 minutes per slide - too long for audience engagement!"

# Calculate recommended slides
puts "\n📊 AI Fix Mode Analysis:".cyan
interface = ISpeaker::ConsoleInterface.new
recommended = interface.send(:calculate_recommended_slides, talk.duration_minutes)

puts "   Recommended slides: #{recommended} (1-2 minutes per slide)".green
puts "   Need to add: #{recommended - talk.slides.length} more slides".yellow

# Show how AI Fix Mode would help
puts "\n🛠️  AI Fix Mode Options:".blue.bold

puts "\n1. Add Slides at Specific Positions:".blue
puts "   • Add 3 slides after \"Introduction\" to expand on prerequisites"
puts "   • Add 5 slides in \"Profiling Tools\" section with demos"
puts "   • Add 4 slides showing real-world examples"

puts "\n2. Expand Specific Sections:".blue
puts "   • Expand \"Memory Management\" with GC deep-dive (+ 6 slides)"
puts "   • Expand \"Algorithm Optimization\" with case studies (+ 5 slides)"
puts "   • Add practical exercises throughout (+ 4 slides)"

puts "\n3. Fill Gaps Between Slides:".blue
puts "   • Add transition slides between major topics"
puts "   • Include recap slides after complex sections"
puts "   • Add interactive Q&A checkpoints"

puts "\n4. Generate Complete Set (#{recommended} slides):".blue
puts "   • AI analyzes current structure"
puts "   • Identifies missing topics and depth"
puts "   • Creates comprehensive presentation flow"
puts "   • Adds examples, exercises, and interactions"

# Simulate what the expanded structure might look like
puts "\n📝 Example Expanded Structure (first 20 slides):".green
expanded_structure = [
  "1. Title Slide - Advanced Ruby Performance",
  "2. About Me / Introduction",
  "3. Agenda Overview",
  "4. Why Performance Matters",
  "5. Performance Myths in Ruby",
  "6. Setting Performance Goals",
  "7. Introduction to Profiling",
  "8. ruby-prof Deep Dive",
  "9. ruby-prof Demo: CPU Profiling",
  "10. ruby-prof Demo: Memory Profiling",
  "11. stackprof Overview",
  "12. stackprof Demo: Flame Graphs",
  "13. memory_profiler Basics",
  "14. memory_profiler Demo: Finding Leaks",
  "15. Profiling Best Practices",
  "16. Quick Exercise: Profile Your Code",
  "17. Understanding Ruby's GC",
  "18. GC Tuning Parameters",
  "19. Object Allocation Patterns",
  "20. Memory Leak Detection..."
]

expanded_structure.each { |slide| puts "   #{slide}".light_blue }
puts "   ... and #{recommended - 20} more slides".light_blue

# Benefits
puts "\n✨ Benefits of Proper Slide Count:".green.bold
puts "• Better pacing - audience stays engaged"
puts "• More examples and practical demos"
puts "• Interactive elements every 5-10 minutes"
puts "• Deeper coverage of complex topics"
puts "• Time for Q&A and discussions"
puts "• Professional presentation structure"

# Show specific expansion example
puts "\n🔍 Example: Expanding \"Memory Management\" Section".yellow
puts "\nOriginal (1 slide):".red
puts "   • GC tuning"
puts "   • Object allocation"
puts "   • Memory leaks"

puts "\nExpanded (7 slides):".green
memory_expansion = [
  "1. Memory Management Overview",
  "2. How Ruby's GC Works - Mark & Sweep",
  "3. GC Tuning Parameters Deep Dive",
  "4. Demo: Monitoring GC Performance",
  "5. Object Allocation Best Practices",
  "6. Case Study: Reducing Memory Usage by 50%",
  "7. Exercise: Find the Memory Leak"
]
memory_expansion.each { |slide| puts "   #{slide}".light_green }

# Usage instructions
puts "\n💡 How to Use AI Fix Mode:".cyan.bold
puts "1. Create or load your talk"
puts "2. Go to Main Menu → AI assistance"
puts "3. Select \"AI Fix Mode - Add/Insert multiple slides\""
puts "4. Choose your expansion strategy"
puts "5. AI generates contextually appropriate slides"
puts "6. Review and adjust as needed"

puts "\n🎯 Pro Tips:".blue
puts "• Start with \"Generate complete set\" for best results"
puts "• Use \"Expand sections\" for deep-dives on complex topics"
puts "• Use \"Fill gaps\" to improve flow and transitions"
puts "• Always review AI suggestions before accepting"

puts "\n🚀 Result:".green.bold
puts "Transform a basic 7-slide outline into a comprehensive #{recommended}-slide"
puts "presentation perfectly paced for your #{talk.duration_minutes}-minute talk!"

# Clean up
puts "\n✅ Demo complete!".green.bold
puts "AI Fix Mode helps create professional, well-paced presentations.".light_blue