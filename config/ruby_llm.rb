# frozen_string_literal: true

# RubyLLM Configuration for i_speaker
#
# This file shows how to configure RubyLLM for use with i_speaker.
# Copy this to your project and uncomment the providers you want to use.
#
# For more details, see: https://github.com/ankane/ruby_llm

require "ruby_llm"

RubyLLM.configure do |config|
  # --- Provider API Keys ---
  # Provide keys ONLY for the providers you intend to use.
  # Using environment variables (ENV.fetch) is highly recommended.

  # Local Ollama instance (primary)
  config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", "http://localhost:11434/api")

  # OpenAI (fallback)
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
  # config.openai_organization_id = ENV.fetch('OPENAI_ORGANIZATION_ID', nil)
  # config.openai_project_id = ENV.fetch('OPENAI_PROJECT_ID', nil)

  # Anthropic Claude
  # config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)

  # Google Gemini
  # config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)

  # DeepSeek
  # config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)

  # OpenRouter (access to many models)
  # config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)

  # --- Default Models ---
  # Used by i_speaker's AI features when no model is specified
  config.default_model = ENV.fetch("DEFAULT_AI_MODEL", "gemma3:latest") # Using local Ollama model

  # --- Connection Settings ---
  config.request_timeout = 120  # Request timeout in seconds
  config.max_retries = 3        # Max retries on network errors

  # --- Logging (optional) ---
  # config.log_level = :info
end

# Validate configuration on load
begin
  # Test that at least one provider is configured
  RubyLLM.chat
  puts "✅ RubyLLM configured successfully for i_speaker".green if defined?(String.colorize)
rescue RubyLLM::ConfigurationError => e
  puts "⚠️  RubyLLM configuration incomplete: #{e.message}"
  puts "   AI features will be disabled in i_speaker."
  puts "   Please set up at least one API key in your environment or this config file."
rescue StandardError => e
  puts "⚠️  RubyLLM setup issue: #{e.message}"
end
