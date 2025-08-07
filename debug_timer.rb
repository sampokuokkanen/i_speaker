#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/i_speaker/console_interface"

# Test the timer formatting directly
console = ISpeaker::ConsoleInterface.new

puts "Testing timer formatting:"
puts

# Test with different elapsed times
test_cases = [0, 30, 60, 125, 3600, 3665]

test_cases.each do |elapsed_seconds|
  minutes = elapsed_seconds / 60
  seconds = elapsed_seconds % 60
  
  puts "Input: #{elapsed_seconds} seconds (#{minutes}:#{seconds})"
  
  # Test without estimation
  result1 = console.send(:format_timer, elapsed_seconds, false)
  puts "  Not paused: #{result1}"
  
  # Test paused
  result2 = console.send(:format_timer, elapsed_seconds, true)
  puts "  Paused: #{result2}"
  
  # Test with estimation (slide 10 of 50, 30min duration)
  result3 = console.send(:format_timer, elapsed_seconds, false, 10, 50, 30)
  puts "  With estimation: #{result3}"
  
  puts
end

puts "Testing live timer calculation:"
start_time = Time.now
5.times do |i|
  sleep(1)
  elapsed_seconds = (Time.now - start_time).to_i
  timer_display = console.send(:format_timer, elapsed_seconds, false)
  puts "Second #{i+1}: #{timer_display}"
end