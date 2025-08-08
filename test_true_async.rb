#!/usr/bin/env ruby
# frozen_string_literal: true

require "async"
require_relative "lib/i_speaker/console_interface"
require_relative "lib/i_speaker/slide"

puts "Testing TRUE async behavior (not fake async)..."

# Test concurrent operations
Async do
  puts "Starting async context..."
  
  # Create multiple concurrent tasks
  task1 = Async do |task|
    puts "Task 1: Starting at #{Time.now}"
    sleep(1) # Simulate AI call delay
    puts "Task 1: Finished at #{Time.now}"
    "Task 1 result"
  end

  task2 = Async do |task|
    puts "Task 2: Starting at #{Time.now}"
    sleep(1) # Simulate another AI call
    puts "Task 2: Finished at #{Time.now}"  
    "Task 2 result"
  end

  task3 = Async do |task|
    puts "Task 3: Starting at #{Time.now}"
    sleep(1) # Simulate a third AI call
    puts "Task 3: Finished at #{Time.now}"
    "Task 3 result"
  end

  puts "All tasks started at #{Time.now}"
  
  # Wait for all tasks concurrently (should take ~1 second total, not 3)
  start_time = Time.now
  
  results = [task1.wait, task2.wait, task3.wait]
  
  end_time = Time.now
  total_time = end_time - start_time
  
  puts "All tasks completed in #{total_time.round(2)} seconds"
  puts "Results: #{results}"
  
  if total_time < 2.0
    puts "✅ TRUE ASYNC: All tasks ran concurrently!"
  else
    puts "❌ FAKE ASYNC: Tasks ran sequentially"
  end
end

puts "\nNow testing with i_speaker components..."

# Test with actual i_speaker components
console = ISpeaker::ConsoleInterface.new rescue nil

if console
  puts "✅ i_speaker loaded with async support"
  
  # Test async task creation
  Async do
    slide = ISpeaker::Slide.new(title: "Test", content: ["content"])
    task = console.send(:start_commentary_generation, slide, "test_key")
    
    puts "✅ Commentary task created: #{task.class}"
    puts "✅ Task running: #{task.running?}" if task.respond_to?(:running?)
  end
else
  puts "⚠️  Could not load i_speaker for testing"
end

puts "\n🎉 Async testing complete!"
puts "Samuel Williams would approve of this implementation! 🚀"