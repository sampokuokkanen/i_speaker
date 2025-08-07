# frozen_string_literal: true

require "open3"
require "colorize"

module ISpeaker
  # Module for syntax highlighting code blocks using cli-highlight
  module SyntaxHighlighter
    class << self
      def available?
        @available ||= system("which cli-highlight > /dev/null 2>&1") ||
                       File.exist?("/opt/homebrew/lib/node_modules/cli-highlight/bin/highlight")
      end

      def highlight(code, language: nil)
        return simple_highlight(code, language) if code.nil? || code.strip.empty?

        begin
          # Use cli-highlight to syntax highlight the code
          # Try different possible commands
          cmd = if system("which cli-highlight > /dev/null 2>&1")
                  ["cli-highlight"]
                elsif File.exist?("/opt/homebrew/lib/node_modules/cli-highlight/bin/highlight")
                  ["/opt/homebrew/lib/node_modules/cli-highlight/bin/highlight"]
                else
                  ["highlight"] # fallback
                end

          cmd += ["-l", language.to_s] if language

          stdout, _stderr, status = Open3.capture3(*cmd, stdin_data: code)

          if status.success? && stdout.chomp != code.strip
            stdout.chomp
          else
            # Fallback to simple highlighting if cli-highlight didn't work
            simple_highlight(code, language)
          end
        rescue StandardError
          # Fallback to simple highlighting if any error occurs
          simple_highlight(code, language)
        end
      end

      # Simple fallback highlighter for basic Ruby syntax
      def simple_highlight(code, language = nil)
        return code if code.nil? || code.strip.empty?

        # Only do simple highlighting for Ruby
        return code unless language.to_s.downcase == "ruby"

        # Apply basic Ruby syntax highlighting
        highlighted = code.dup

        # Keywords
        highlighted.gsub!(
          /\\b(def|end|class|module|if|unless|else|elsif|case|when|while|until|for|do|begin|rescue|ensure|return|yield|break|next|puts|print|p|require|load)\\b/, &:blue
        )

        # Strings
        highlighted.gsub!(/(["'])((?:\\\\.|(?!\\1)[^\\])*)\\1/, &:green)

        # Numbers
        highlighted.gsub!(/\\b\\d+(_\\d+)*(\\.\\d+)?\\b/, &:yellow)

        # Comments
        highlighted.gsub!(/#.*$/, &:light_black)

        # Symbols
        highlighted.gsub!(/:([a-zA-Z_]\\w*)/, &:cyan)

        highlighted
      end

      def detect_language(content)
        # Simple language detection based on content patterns
        case content
        when /^\s*#.*frozen_string_literal/
          "ruby"
        when /def\s+\w+|class\s+\w+|module\s+\w+|puts\s+|require\s+/
          "ruby"
        when /function\s+\w+|const\s+\w+|let\s+\w+|var\s+\w+/
          "javascript"
        when /import\s+\w+|from\s+\w+|def\s+\w+.*:/
          "python"
        when /<\w+.*>/
          "html"
        when /SELECT\s+|INSERT\s+|UPDATE\s+|DELETE\s+/i
          "sql"
        end
      end

      def format_code_block(content, language: nil)
        # Auto-detect language if not specified
        detected_language = language || detect_language(content)

        # Apply syntax highlighting
        highlighted = highlight(content, language: detected_language)

        # Add some visual styling for code blocks
        lines = highlighted.split("\n")
        formatted_lines = lines.map.with_index do |line, index|
          line_num = (index + 1).to_s.rjust(2)
          "#{line_num.light_black} │ #{line}"
        end

        # Add border
        max_width = formatted_lines.map { |line| line.gsub(/\e\[[0-9;]*m/, "").length }.max || 0
        border = "─" * [max_width + 4, 50].min

        [
          "┌#{border}┐".light_black,
          *formatted_lines,
          "└#{border}┘".light_black
        ].join("\n")
      end
    end
  end
end
