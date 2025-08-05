# frozen_string_literal: true

require "drb/drb"
require "colorize"

module ISpeaker
  # DRuby server for sharing presentation state with notes viewer
  class PresentationServer
    attr_accessor :current_slide_index, :total_slides, :talk_title, :current_slide, :server_object_id

    def initialize
      self.current_slide_index = 0
      self.total_slides = 0
      self.talk_title = ""
      self.current_slide = nil
      self.server_object_id = "server_#{Time.now.to_i}_#{rand(1000)}"
      @server_thread = nil
    end

    def start_server(port = 9000)
      @server_uri = "druby://localhost:#{port}"

      # Use this instance as the front object
      front_object = self
      
      # Start DRuby service
      DRb.start_service(@server_uri, front_object)
      @server_thread = Thread.new { DRb.thread.join }

      # Give the server a moment to fully initialize
      sleep(0.5)

      puts "\n🌐 Notes server started on #{@server_uri}".green
      puts "   Run 'i_speaker_notes #{port}' in another terminal to view notes".light_blue

      # Return the front object that clients will connect to
      DRb.front
    rescue StandardError => e
      puts "⚠️  Could not start notes server: #{e.message}".yellow
      nil
    end

    def stop_server
      DRb.stop_service if DRb.thread
      @server_thread&.kill
    end

    # Called by main presentation to update current slide
    def update_slide(slide_index, slide, total_slides, talk_title)
      self.current_slide_index = slide_index
      self.current_slide = slide
      self.total_slides = total_slides
      self.talk_title = talk_title
    end

    # Called by notes viewer to get current state
    def get_current_state
      state = {
        slide_index: self.current_slide_index,
        slide_number: self.current_slide_index + 1,
        total_slides: self.total_slides,
        talk_title: self.talk_title,
        slide_title: self.current_slide&.title || "",
        slide_notes: self.current_slide&.notes || "",
        slide_content: self.current_slide&.content || [],
        slide_type: self.current_slide&.slide_type || :content,
        server_object_id: self.server_object_id
      }
      
      
      state
    end

  end
end
