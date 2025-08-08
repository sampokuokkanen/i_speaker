# frozen_string_literal: true

require "json"
require_relative "slide"

module ISpeaker
  class Talk
    attr_accessor :title, :description, :slides, :target_audience, :duration_minutes

    def initialize(title: "", description: "", target_audience: "", duration_minutes: 30)
      @title = title
      @description = description
      @target_audience = target_audience
      @duration_minutes = duration_minutes
      @slides = []
    end

    def add_slide(slide = nil)
      slide = Slide.new if slide.nil?
      @slides << slide
      slide
    end

    def insert_slide_at(position, slide = nil)
      # Ensure position is within bounds
      position = [[position, 0].max, @slides.length].min

      slide = Slide.new if slide.nil?

      @slides.insert(position, slide)
      renumber_slides
      slide
    end

    def remove_slide(index)
      return unless valid_slide_index?(index)

      removed_slide = @slides.delete_at(index)
      renumber_slides
      removed_slide
    end

    def move_slide(from_index, to_index)
      return false unless valid_slide_index?(from_index) && valid_slide_index?(to_index)

      slide = @slides.delete_at(from_index)
      @slides.insert(to_index, slide)
      renumber_slides
      true
    end

    def get_slide(index)
      return unless valid_slide_index?(index)

      @slides[index]
    end

    def slide_count
      @slides.length
    end

    def estimated_duration
      # Rough estimate: 2-3 minutes per slide
      base_minutes = @slides.length * 2.5
      # Add time for Q&A if it's a longer talk
      qa_time = @slides.length > 10 ? 5 : 0
      (base_minutes + qa_time).round
    end

    def completion_status
      completed_slides = @slides.count(&:complete?)
      total_slides = @slides.length

      return "No slides created yet" if total_slides.zero?

      "#{completed_slides}/#{total_slides} slides completed"
    end

    def to_hash
      {
        title: @title,
        description: @description,
        target_audience: @target_audience,
        duration_minutes: @duration_minutes,
        slides: @slides.map(&:to_hash),
        estimated_duration: estimated_duration,
        completion_status: completion_status,
      }
    end

    def save_to_file(filename)
      # Check if file exists and has been modified externally
      if File.exist?(filename)
        begin
          current_content = File.read(filename)
          # Parse existing file to check if it's different from our current state
          existing_data = JSON.parse(current_content, symbolize_names: true)
          our_data = to_hash

          # Simple comparison - if the slide count or basic structure differs, warn about conflict
          if existing_data[:slides]&.length != our_data[:slides]&.length ||
             existing_data[:title] != our_data[:title] ||
             existing_data[:description] != our_data[:description]

            # Create backup of current file
            backup_filename = "#{filename}.backup_#{Time.now.strftime("%Y%m%d_%H%M%S")}"
            File.write(backup_filename, current_content)
            puts "\n⚠️  File conflict detected! Created backup: #{backup_filename}".yellow
            puts "External changes detected in #{filename}. Proceeding with save...".yellow
          end
        rescue JSON::ParserError
          # If we can't parse the existing file, just proceed with save
          puts "\n⚠️  Existing file appears corrupted. Overwriting...".yellow
        end
      end

      # Use fast generation in production, pretty in development
      json_content = ENV["RACK_ENV"] == "production" ? JSON.generate(to_hash) : JSON.pretty_generate(to_hash)
      File.write(filename, json_content)
    end

    def self.load_from_file(filename)
      return unless File.exist?(filename)

      data = JSON.parse(File.read(filename), symbolize_names: true)
      talk = new(
        title: data[:title],
        description: data[:description],
        target_audience: data[:target_audience],
        duration_minutes: data[:duration_minutes],
      )

      data[:slides]&.each do |slide_data|
        slide = ISpeaker::Slide.new(
          title: slide_data[:title],
          content: slide_data[:content],
          notes: slide_data[:notes],
          image_path: slide_data[:image_path],
          slide_type: slide_data[:slide_type] || :content,
          demo_code: slide_data[:demo_code]
        )
        talk.slides << slide
      end

      talk
    end

    def summary
      slides_summary = @slides.map(&:display_summary).join("\n")
      estimated = estimated_duration

      <<~SUMMARY
        Talk: #{@title}
        Description: #{@description}
        Target Audience: #{@target_audience}
        Planned Duration: #{@duration_minutes} minutes
        Estimated Duration: #{estimated} minutes

        Slides (#{@slides.length}):
        #{slides_summary.empty? ? "No slides yet" : slides_summary}
      SUMMARY
    end

    private

    def valid_slide_index?(index)
      index >= 0 && index < @slides.length
    end

    def renumber_slides
      # No longer needed - slide numbers are determined by position
    end
  end
end
