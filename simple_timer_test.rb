#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple timer test without full initialization

def format_timer(elapsed_seconds, paused = false, current_slide = nil, total_slides = nil, duration_minutes = nil)
  minutes = elapsed_seconds / 60
  seconds = elapsed_seconds % 60
  timer_text = format("%02d:%02d", minutes, seconds)

  # Calculate estimated remaining time if we have the data
  remaining_text = ""
  if current_slide && total_slides && duration_minutes && total_slides.positive?
    # Calculate progress and estimated remaining time
    progress = (current_slide + 1).to_f / total_slides
    estimated_total_seconds = duration_minutes * 60
    estimated_remaining_seconds = (estimated_total_seconds * (1 - progress)).to_i

    if estimated_remaining_seconds.positive?
      rem_minutes = estimated_remaining_seconds / 60
      rem_seconds = estimated_remaining_seconds % 60
      remaining_text = " | Est. remaining: #{format("%02d:%02d", rem_minutes, rem_seconds)}"
    end
  end

  if paused
    "⏸️  #{timer_text}#{remaining_text}"
  else
    "⏱️  #{timer_text}#{remaining_text}"
  end
end

puts "Testing timer formatting:"
puts

# Test with different elapsed times
test_cases = [0, 30, 60, 125, 3600, 3665]

test_cases.each do |elapsed_seconds|
  minutes = elapsed_seconds / 60
  seconds = elapsed_seconds % 60
  
  puts "Input: #{elapsed_seconds} seconds (#{minutes}:#{seconds})"
  
  # Test without estimation
  result1 = format_timer(elapsed_seconds, false)
  puts "  Not paused: #{result1}"
  
  # Test paused
  result2 = format_timer(elapsed_seconds, true)
  puts "  Paused: #{result2}"
  
  # Test with estimation (slide 10 of 50, 30min duration)
  result3 = format_timer(elapsed_seconds, false, 10, 50, 30)
  puts "  With estimation: #{result3}"
  
  puts
end

puts "Testing live timer calculation:"
start_time = Time.now
total_pause_duration = 0

5.times do |i|
  sleep(1)
  elapsed_seconds = (Time.now - start_time - total_pause_duration).to_i
  timer_display = format_timer(elapsed_seconds, false)
  puts "Second #{i+1}: elapsed_seconds=#{elapsed_seconds}, display=#{timer_display}"
end