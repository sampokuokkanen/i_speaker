#!/usr/bin/env ruby
# frozen_string_literal: true

require "async"

puts "🎭 Proving TRUE async behavior vs FAKE async..."

# FAKE ASYNC (what we had before)
puts "\n❌ FAKE ASYNC EXAMPLE:"
puts "This looks async but runs sequentially:"

fake_async_start = Time.now
Async do
  puts "  Starting fake async tasks..."
  
  # These look async but block each other
  result1 = "Task 1 (blocking call)"
  sleep(0.5) # Simulate sync AI call
  puts "  #{result1} finished"
  
  result2 = "Task 2 (blocking call)"  
  sleep(0.5) # Another sync AI call
  puts "  #{result2} finished"
  
  result3 = "Task 3 (blocking call)"
  sleep(0.5) # Another sync AI call
  puts "  #{result3} finished"
end
fake_time = Time.now - fake_async_start
puts "  Total time: #{fake_time.round(2)} seconds (should be ~1.5s)"

# TRUE ASYNC
puts "\n✅ TRUE ASYNC EXAMPLE:"
puts "This actually runs concurrently:"

true_async_start = Time.now
Async do
  puts "  Starting true async tasks..."
  
  # These truly run concurrently
  task1 = Async { sleep(0.5); "Task 1 result" }
  task2 = Async { sleep(0.5); "Task 2 result" }  
  task3 = Async { sleep(0.5); "Task 3 result" }
  
  # Wait for all to complete concurrently
  results = [task1.wait, task2.wait, task3.wait]
  puts "  All tasks completed: #{results}"
end
true_time = Time.now - true_async_start
puts "  Total time: #{true_time.round(2)} seconds (should be ~0.5s)"

puts "\n📊 RESULTS:"
if true_time < fake_time * 0.6
  puts "✅ TRUE ASYNC: #{true_time.round(2)}s vs #{fake_time.round(2)}s"
  puts "   Tasks ran concurrently, not sequentially!"
  puts "   Samuel Williams would approve! 🚀"
else
  puts "❌ Still fake async - tasks are blocking each other"
end

puts "\n🎯 KEY INSIGHT:"
puts "Just wrapping sync code in Async do...end doesn't make it async!"
puts "You need to actually use async I/O operations (like Async::HTTP)"
puts "or create concurrent tasks that can actually yield to each other."