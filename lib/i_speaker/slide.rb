# frozen_string_literal: true

module ISpeaker
  class Slide
    attr_accessor :title, :content, :notes, :number

    def initialize(title: "", content: [], notes: "", number: nil)
      @title = title
      @content = content.is_a?(Array) ? content : [content].compact
      @notes = notes
      @number = number
    end

    def add_content(item)
      @content << item unless item.nil? || item.strip.empty?
    end

    def remove_content(index)
      @content.delete_at(index) if index >= 0 && index < @content.length
    end

    def update_content(index, new_content)
      @content[index] = new_content if index >= 0 && index < @content.length
    end

    def to_hash
      {
        title: @title,
        content: @content,
        notes: @notes,
        number: @number,
      }
    end

    def to_s
      content_text = @content.empty? ? "  (No content yet)" : @content.map { |item| "  • #{item}" }.join("\n")
      notes_text = @notes.empty? ? "" : "\n\nNotes: #{@notes}"

      "#{@title}\n#{content_text}#{notes_text}"
    end

    def display_summary
      content_preview = @content.first(2).join(", ")
      content_preview + "..." if @content.length > 2
      "#{@number}. #{@title} (#{@content.length} points)"
    end

    def empty?
      @title.strip.empty? && @content.empty? && @notes.strip.empty?
    end

    def complete?
      !@title.strip.empty? && !@content.empty?
    end
  end
end
