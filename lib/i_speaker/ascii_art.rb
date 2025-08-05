# frozen_string_literal: true

module ISpeaker
  module AsciiArt
    # Simple ASCII art generator for larger text display
    LARGE_LETTERS = {
      'A' => ["  ▄▄▄  ", " ▐█ █▌ ", "▐█▄▄█▌", "▐█  █▌"],
      'B' => ["▐███▌ ", "▐█ █▌ ", "▐███▌ ", "▐███▌ "],
      'C' => [" ▄██▄ ", "▐█    ", "▐█    ", " ▀██▀ "],
      'D' => ["▐███▌ ", "▐█  █▌", "▐█  █▌", "▐███▌ "],
      'E' => ["▐████▌", "▐█▄▄  ", "▐█▀▀  ", "▐████▌"],
      'F' => ["▐████▌", "▐█▄▄  ", "▐█    ", "▐█    "],
      'G' => [" ▄██▄ ", "▐█    ", "▐█ ▄█▌", " ▀██▀ "],
      'H' => ["▐█  █▌", "▐████▌", "▐█  █▌", "▐█  █▌"],
      'I' => ["▐███▌", " ▐█▌ ", " ▐█▌ ", "▐███▌"],
      'J' => ["  ███▌", "   █▌ ", "▐▌ █▌ ", " ▀█▀  "],
      'K' => ["▐█ ▄█▌", "▐██▀  ", "▐██▄  ", "▐█ ▀█▌"],
      'L' => ["▐█    ", "▐█    ", "▐█    ", "▐████▌"],
      'M' => ["▐█▌▐█▌", "▐█▀▀█▌", "▐█  █▌", "▐█  █▌"],
      'N' => ["▐█▌ █▌", "▐██ █▌", "▐█▐██▌", "▐█ ▐█▌"],
      'O' => [" ▄██▄ ", "▐█  █▌", "▐█  █▌", " ▀██▀ "],
      'P' => ["▐███▌ ", "▐█ █▌ ", "▐███▌ ", "▐█    "],
      'Q' => [" ▄██▄ ", "▐█  █▌", "▐█ ▐█▌", " ▀███▌"],
      'R' => ["▐███▌ ", "▐█ █▌ ", "▐███▌ ", "▐█ ▀█▌"],
      'S' => [" ▄██▄ ", "▐█▄▄  ", "  ▀▀█▌", " ▀██▀ "],
      'T' => ["▐████▌", "  ▐█▌ ", "  ▐█▌ ", "  ▐█▌ "],
      'U' => ["▐█  █▌", "▐█  █▌", "▐█  █▌", " ▀██▀ "],
      'V' => ["▐█  █▌", "▐█  █▌", " ▐██▌ ", "  ▐▌  "],
      'W' => ["▐█  █▌", "▐█  █▌", "▐█▀▀█▌", "▐█▌▐█▌"],
      'X' => ["▐█  █▌", " ▐██▌ ", " ▐██▌ ", "▐█  █▌"],
      'Y' => ["▐█  █▌", " ▐██▌ ", "  ▐█▌ ", "  ▐█▌ "],
      'Z' => ["▐████▌", "  ▄█▌ ", " ▐█▄  ", "▐████▌"],
      ' ' => ["    ", "    ", "    ", "    "],
      '!' => ["▐█▌", "▐█▌", "   ", "▐█▌"],
      '?' => [" ▄██▄ ", "   █▌ ", "  ▐▌  ", "  ▐▌  "],
      '.' => ["   ", "   ", "   ", "▐█▌"],
      ',' => ["   ", "   ", "▐█▌", "▐▌ "],
      ':' => ["   ", "▐█▌", "   ", "▐█▌"],
      ';' => ["   ", "▐█▌", "▐█▌", "▐▌ "],
      '-' => ["    ", "    ", "▐██▌", "    "],
      '+' => ["  ▐▌  ", "▐▄█▄▌", "  ▐▌  ", "     "],
      '=' => ["     ", "▐███▌", "▐███▌", "     "],
      '0' => [" ▄██▄ ", "▐█▐▌█▌", "▐█▌▐█▌", " ▀██▀ "],
      '1' => [" ▄█▌  ", "▐██▌  ", " ▐█▌  ", "▐███▌ "],
      '2' => [" ▄██▄ ", "   █▌ ", " ▄█▀  ", "▐████▌"],
      '3' => [" ▄██▄ ", "  ▀█▌ ", "   █▌ ", " ▀██▀ "],
      '4' => ["▐█ ▐█▌", "▐████▌", "   ▐█▌", "   ▐█▌"],
      '5' => ["▐████▌", "▐█▄▄  ", "  ▀▀█▌", " ▀██▀ "],
      '6' => [" ▄██▄ ", "▐█    ", "▐███▌ ", " ▀██▀ "],
      '7' => ["▐████▌", "   █▌ ", "  ▐▌  ", " ▐▌   "],
      '8' => [" ▄██▄ ", " ▀██▀ ", " ▄██▄ ", " ▀██▀ "],
      '9' => [" ▄██▄ ", " ▀███▌", "    █▌", " ▀██▀ "]
    }.freeze

    def self.to_large_text(text, color = :green)
      return "" if text.nil? || text.empty?
      
      # Convert to uppercase for consistency
      text = text.upcase
      
      # Split into lines if text is too long
      max_width = 15  # Maximum characters per line
      lines = text.scan(/.{1,#{max_width}}/)
      
      result = []
      
      lines.each do |line|
        # Build 4 rows for this line
        rows = ["", "", "", ""]
        
        line.each_char do |char|
          letter_art = LARGE_LETTERS[char] || LARGE_LETTERS[' ']
          letter_art.each_with_index do |row, i|
            rows[i] += row
          end
        end
        
        # Add colored rows to result
        rows.each do |row|
          case color
          when :green
            result << row.green
          when :red
            result << row.red
          when :blue
            result << row.blue
          when :yellow
            result << row.yellow
          when :cyan
            result << row.cyan
          when :white
            result << row.white
          else
            result << row
          end
        end
        
        # Add spacing between lines
        result << "" if lines.length > 1
      end
      
      result
    end
    
    def self.center_large_text(text, terminal_width, color = :green)
      lines = to_large_text(text, color)
      centered_lines = []
      
      lines.each do |line|
        visible_length = line.gsub(/\e\[[0-9;]*m/, '').length
        padding = [(terminal_width - visible_length) / 2, 0].max
        centered_lines << (" " * padding) + line
      end
      
      centered_lines
    end
  end
end