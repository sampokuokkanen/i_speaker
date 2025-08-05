# frozen_string_literal: true

require_relative "i_speaker/version"
require_relative "i_speaker/ai_persona"
require_relative "i_speaker/sample_talks"
require_relative "i_speaker/talk"
require_relative "i_speaker/slide"
require_relative "i_speaker/ollama_client"
require_relative "i_speaker/console_interface"
require_relative "i_speaker/presentation_server"
require_relative "i_speaker/notes_viewer"

module ISpeaker
  class Error < StandardError; end
end
