# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module ISpeaker
  # Simple client for interacting with Ollama API directly
  class OllamaClient
    def initialize(base_url = 'http://localhost:11434')
      @base_url = base_url
      @default_model = 'llama3.2:latest'
    end

    def available?
      uri = URI("#{@base_url}/api/tags")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5
      
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      response.code == '200'
    rescue
      false
    end

    def chat(model: @default_model, messages:, system: nil)
      uri = URI("#{@base_url}/api/chat")
      
      # Add system message if provided
      chat_messages = []
      chat_messages << { role: 'system', content: system } if system
      chat_messages.concat(messages)
      
      request_body = {
        model: model,
        messages: chat_messages,
        stream: false
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 120  # Long timeout for AI processing
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = request_body.to_json

      response = http.request(request)
      if response.code == '200'
        JSON.parse(response.body)
      else
        raise "Ollama API error: #{response.code} - #{response.body}"
      end
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Ollama: #{e.message}"
    rescue Net::ReadTimeout
      raise "Ollama request timed out. The model might be busy or the request too complex."
    end

    def ask(prompt, model: @default_model, system: nil)
      messages = [{ role: 'user', content: prompt }]
      response = chat(model: model, messages: messages, system: system)
      response.dig('message', 'content') || ''
    end
  end
end