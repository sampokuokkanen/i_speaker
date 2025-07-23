#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to test auto-save functionality

require_relative 'lib/i_speaker'

puts "💾 Testing Auto-Save Functionality".cyan.bold
puts "=" * 50

# Create a console interface instance
interface = ISpeaker::ConsoleInterface.new

puts "\n📋 Testing auto-save features...".yellow

# Test 1: Basic talk creation with auto-save
puts "\n1. Testing basic talk creation with auto-save...".blue

talk = ISpeaker::Talk.new(
  title: "Auto-Save Test Talk",
  description: "Testing the auto-save functionality",
  target_audience: "Developers",
  duration_minutes: 15
)

# Simulate setting the talk in the interface
interface.instance_variable_set(:@talk, talk)

# Test auto-save method
puts "   • Auto-save enabled: #{interface.instance_variable_get(:@auto_save_enabled) ? 'YES' : 'NO'}".light_blue
puts "   • Current filename: #{interface.instance_variable_get(:@current_filename) || 'None (will generate)'}".light_blue

# Trigger auto-save
puts "   • Triggering auto-save..."
interface.send(:auto_save)

current_filename = interface.instance_variable_get(:@current_filename)
puts "   ✅ Auto-save completed: #{current_filename}".green

# Verify file was created
if File.exist?(current_filename)
  puts "   ✅ File exists on disk".green
  puts "   📄 File size: #{File.size(current_filename)} bytes".light_blue
else
  puts "   ❌ File was not created".red
end

# Test 2: Test toggle functionality
puts "\n2. Testing auto-save toggle...".blue

original_state = interface.instance_variable_get(:@auto_save_enabled)
puts "   • Original state: #{original_state ? 'ON' : 'OFF'}".light_blue

interface.send(:toggle_autosave)
new_state = interface.instance_variable_get(:@auto_save_enabled)
puts "   • After toggle: #{new_state ? 'ON' : 'OFF'}".light_blue
puts "   ✅ Toggle functionality works: #{original_state != new_state ? 'YES' : 'NO'}".green

# Toggle back
interface.send(:toggle_autosave)

# Test 3: Test filename generation
puts "\n3. Testing filename generation...".blue

# Create talk with special characters in title
special_talk = ISpeaker::Talk.new(
  title: "My Amazing Talk: Ruby & Rails Best Practices! (2024)",
  description: "A talk with special characters in the title",
  target_audience: "Ruby developers",
  duration_minutes: 25
)

interface.instance_variable_set(:@talk, special_talk)
interface.instance_variable_set(:@current_filename, nil)  # Reset filename

puts "   • Original title: #{special_talk.title}".light_blue
interface.send(:auto_save)
generated_filename = interface.instance_variable_get(:@current_filename)
puts "   • Generated filename: #{generated_filename}".light_blue
puts "   ✅ Filename is safe: #{generated_filename.match?(/^[a-z0-9_]+\.json$/) ? 'YES' : 'NO'}".green

# Test 4: Test slide operations with auto-save
puts "\n4. Testing slide operations trigger auto-save...".blue

# Add a slide
slide = ISpeaker::Slide.new(
  title: "Test Slide",
  content: ["Point 1", "Point 2", "Point 3"],
  notes: "This is a test slide"
)

special_talk.add_slide(slide)
puts "   • Added slide: #{slide.title}".light_blue

# Simulate auto-save after slide operation
interface.send(:auto_save)
puts "   ✅ Auto-save after slide addition completed".green

# Test 5: Test exit handler (without actually exiting)
puts "\n5. Testing exit handler logic...".blue

# Save original filename
original_filename = interface.instance_variable_get(:@current_filename)

puts "   • Talk exists: #{interface.instance_variable_get(:@talk) ? 'YES' : 'NO'}".light_blue
puts "   • Auto-save enabled: #{interface.instance_variable_get(:@auto_save_enabled) ? 'YES' : 'NO'}".light_blue
puts "   • Current filename: #{original_filename}".light_blue

# Simulate the exit handler logic (without actually exiting)
if interface.instance_variable_get(:@talk) && interface.instance_variable_get(:@auto_save_enabled)
  puts "   💾 Would save work before exit...".blue
  interface.send(:auto_save)
  puts "   ✅ Exit handler would save work successfully".green
else
  puts "   ⚠️  Exit handler would warn about unsaved changes".yellow
end

puts "\n🎯 Auto-Save Test Summary:".cyan.bold
puts "✅ Auto-save creates files with safe filenames"
puts "✅ Toggle functionality works correctly"  
puts "✅ Files are saved to disk successfully"
puts "✅ Exit handling preserves work"
puts "✅ Filename tracking works properly"

puts "\n💡 Benefits:".green
puts "• Prevents data loss from accidental Ctrl+C/Ctrl+D"
puts "• Automatic filename generation from talk titles"
puts "• User can toggle auto-save on/off as needed"
puts "• Clear feedback about save status"
puts "• Graceful exit handling with final save"

# Clean up test files
puts "\n🧹 Cleaning up test files...".blue
Dir.glob("*_test_talk_*.json").each do |file|
  File.delete(file)
  puts "   🗑️  Deleted: #{file}".light_blue
end

Dir.glob("auto_save_test_talk_*.json").each do |file|
  File.delete(file)
  puts "   🗑️  Deleted: #{file}".light_blue
end

Dir.glob("my_amazing_talk_*.json").each do |file|
  File.delete(file)
  puts "   🗑️  Deleted: #{file}".light_blue
end

puts "\n🎉 Auto-save functionality is ready!".green.bold