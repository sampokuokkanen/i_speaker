#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class SimpleOllamaClient
  def initialize(base_url = 'http://localhost:11434')
    @base_url = base_url
  end

  def chat(model: 'llama3.2:latest', messages:)
    uri = URI("#{@base_url}/api/chat")
    
    request_body = {
      model: model,
      messages: messages,
      stream: false
    }

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = request_body.to_json

    begin
      response = http.request(request)
      if response.code == '200'
        JSON.parse(response.body)
      else
        { error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue => e
      { error: e.message }
    end
  end

  def ask(prompt, model: 'llama3.2:latest')
    messages = [{ role: 'user', content: prompt }]
    response = chat(model: model, messages: messages)
    
    if response.key?('error')
      raise "Ollama error: #{response['error']}"
    else
      response.dig('message', 'content') || 'No response'
    end
  end
end

# Test the client
puts "Testing Ollama connection...".green if defined?(String.colorize)

ollama = SimpleOllamaClient.new
begin
  response = ollama.ask("Say hello in one word")
  puts "✅ Ollama is working! Response: #{response}"
  
  # Test a more complex prompt
  prompt = <<~PROMPT
    You're helping create a presentation titled "Ruby Programming Basics".
    Topic: Introduction to Ruby for beginners
    Audience: New developers
    Duration: 20 minutes

    Create a slide about "Ruby Syntax" with:
    - Title
    - 3-4 key bullet points
    - Speaker notes

    Format as JSON like this:
    {
      "title": "...",
      "content": ["point 1", "point 2", "point 3"],
      "speaker_notes": "..."
    }
  PROMPT

  puts "\nTesting complex prompt..."
  complex_response = ollama.ask(prompt)
  puts "Response: #{complex_response[0..200]}..."

rescue => e
  puts "❌ Error: #{e.message}"
end