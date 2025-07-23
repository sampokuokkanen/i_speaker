# frozen_string_literal: true

require "json"

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
      if slide.nil?
        slide = Slide.new(number: @slides.length + 1)
      else
        slide.number = @slides.length + 1
      end
      @slides << slide
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

      return "No slides created yet" if total_slides == 0

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
      File.write(filename, JSON.pretty_generate(to_hash))
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
        slide = Slide.new(
          title: slide_data[:title],
          content: slide_data[:content],
          notes: slide_data[:notes],
          number: slide_data[:number],
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
      @slides.each_with_index { |slide, index| slide.number = index + 1 }
    end
  end
end
