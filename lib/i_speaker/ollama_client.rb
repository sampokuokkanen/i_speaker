# frozen_string_literal: true

require "async"
require "async/http"
require "json"
require "uri"

module ISpeaker
  # Simple client for interacting with Ollama API directly
  class OllamaClient
    def initialize(base_url = "http://localhost:11434")
      @base_url = base_url
      @default_model = "llama3.2:latest"
    end

    def available?
      return true
      Async do
        available_async
      end.wait
    rescue StandardError
      false
    end

    def available_async
      Async do
        endpoint = Async::HTTP::Endpoint.parse("#{@base_url}/api/tags")
        Async::HTTP::Client.open(endpoint) do |client|
          response = client.get("/api/tags", {}, {})
          response.status == 200
        end
      end
    rescue StandardError
      false
    end

    def chat(messages:, model: @default_model, system: nil)
      uri = URI("#{@base_url}/api/chat")

      # Add system message if provided
      chat_messages = []
      chat_messages << { role: "system", content: system } if system
      chat_messages.concat(messages)

      request_body = {
        model: model,
        messages: chat_messages,
        stream: false
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 120 # Long timeout for AI processing

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = request_body.to_json

      response = http.request(request)
      raise "Ollama API error: #{response.code} - #{response.body}" unless response.code == "200"

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Ollama: #{e.message}"
    rescue Net::ReadTimeout
      raise "Ollama request timed out. The model might be busy or the request too complex."
    end

    def ask(prompt, model: @default_model, system: nil)
      messages = [{ role: "user", content: prompt }]
      response = chat(model: model, messages: messages, system: system)
      response.dig("message", "content") || ""
    end
  end
end
