# frozen_string_literal: true

module ISpeaker
  class Slide
    attr_accessor :title, :content, :notes, :image_path, :slide_type

    def initialize(title: "", content: [], notes: "", image_path: nil, slide_type: :content)
      @title = title
      @content = content.is_a?(Array) ? content : [content].compact
      @notes = notes
      @image_path = image_path
      @slide_type = slide_type # :content, :image, or :mixed
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
        image_path: @image_path,
        slide_type: @slide_type,
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
      "#{@title} (#{@content.length} points)"
    end

    def empty?
      @title.strip.empty? && @content.empty? && @notes.strip.empty?
    end

    def complete?
      case @slide_type.to_s
      when "image"
        !@title.strip.empty? && !@image_path.nil? && File.exist?(@image_path.to_s)
      when "mixed"
        !@title.strip.empty? && (!@content.empty? || (!@image_path.nil? && File.exist?(@image_path.to_s)))
      else
        !@title.strip.empty? && !@content.empty?
      end
    end

    def image_slide?
      %w[image mixed].include?(@slide_type.to_s)
    end

    def has_valid_image?
      !@image_path.nil? && File.exist?(@image_path.to_s)
    end

    def set_image(path)
      if File.exist?(path.to_s)
        @image_path = path
        @slide_type = @content.empty? ? :image : :mixed
        true
      else
        false
      end
    end
  end
end
