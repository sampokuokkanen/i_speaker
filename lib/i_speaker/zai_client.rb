# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ISpeaker
  # Client for interacting with Z AI API
  class ZAIClient
    def initialize(api_key = ENV.fetch("ZAI_API_KEY", nil))
      @api_key = api_key || "fd23d636f6294e10a5449cb2b6fcd505.jpYXwHx793kijAD8"
      @base_url = "https://api.z.ai/api/paas/v4"
      @default_model = "glm-4.5"
    end

    def available?
      return false unless @api_key

      # Test with a minimal request
      uri = URI("#{@base_url}/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"

      test_body = {
        model: @default_model,
        messages: [{ role: "user", content: "test" }],
        max_tokens: 5
      }

      request.body = test_body.to_json
      response = http.request(request)
      response.code == "200"
    rescue StandardError
      false
    end

    def chat(messages:, model: @default_model, system: nil, temperature: 0.7, top_p: 0.8)
      uri = URI("#{@base_url}/chat/completions")

      # Add system message if provided
      chat_messages = []
      chat_messages << { role: "system", content: system } if system
      chat_messages.concat(messages)

      request_body = {
        model: model,
        messages: chat_messages,
        temperature: temperature,
        top_p: top_p
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 120 # Long timeout for AI processing

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = request_body.to_json

      response = http.request(request)
      raise "Z AI API error: #{response.code} - #{response.body}" unless response.code == "200"

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Z AI: #{e.message}"
    rescue Net::ReadTimeout
      raise "Z AI request timed out. The model might be busy or the request too complex."
    end

    def ask(prompt, model: @default_model, system: nil)
      messages = [{ role: "user", content: prompt }]
      response = chat(model: model, messages: messages, system: system)

      # Z AI returns response in OpenAI format
      response.dig("choices", 0, "message", "content") || ""
    end
  end
end
