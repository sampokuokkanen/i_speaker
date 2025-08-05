# frozen_string_literal: true

require "open3"

module ISpeaker
  # Module for handling terminal image display
  module ImageViewer
    VIEWERS = {
      viu: {
        command: "viu",
        args: ["-w", "80"],
        description: "Command-line image viewer (Rust)"
      },
      feh: {
        command: "feh",
        args: ["--scale-down", "--auto-zoom"],
        description: "Lightweight image viewer"
      },
      sxiv: {
        command: "sxiv",
        args: ["-f"],
        description: "Simple X Image Viewer"
      },
      fim: {
        command: "fim",
        args: ["-a"],
        description: "Framebuffer image viewer"
      }
    }.freeze

    class << self
      def available_viewers
        @available_viewers ||= VIEWERS.select { |_name, config| command_available?(config[:command]) }
      end

      def preferred_viewer
        @preferred_viewer ||= detect_best_viewer
      end

      def display_image(image_path)
        return false unless File.exist?(image_path)

        viewer = preferred_viewer
        return false unless viewer

        config = VIEWERS[viewer]
        begin
          # For viu, display inline in terminal
          if viewer == :viu
            system(config[:command], *config[:args], image_path)
          else
            # For GUI viewers, display and wait for user input
            puts "\n📸 Displaying image: #{File.basename(image_path)}".cyan
            puts "Press any key after viewing the image...".light_black

            # Launch viewer in background
            pid = Process.spawn(config[:command], *config[:args], image_path,
                                out: "/dev/null", err: "/dev/null")

            # Wait for keypress
            require "io/console"
            STDIN.getch

            # Kill the viewer process
            begin
              Process.kill("TERM", pid)
            rescue StandardError
              nil
            end
            begin
              Process.wait(pid)
            rescue StandardError
              nil
            end
          end
          true
        rescue StandardError => e
          puts "❌ Error displaying image: #{e.message}".red
          false
        end
      end

      def display_image_info(image_path)
        return unless File.exist?(image_path)

        file_size = File.size(image_path)
        file_size_mb = (file_size / 1024.0 / 1024.0).round(2)

        puts "📷 Image: #{File.basename(image_path)}".light_blue
        puts "   Path: #{image_path}".light_black
        puts "   Size: #{file_size_mb} MB".light_black

        # Try to get image dimensions if imagemagick is available
        return unless command_available?("identify")

        begin
          dimensions = `identify -format "%wx%h" "#{image_path}" 2>/dev/null`.strip
          puts "   Dimensions: #{dimensions}".light_black unless dimensions.empty?
        rescue StandardError
          # Ignore if identify fails
        end
      end

      def create_sample_screenshots
        screenshots_dir = File.join(Dir.pwd, "sample_screenshots")
        Dir.mkdir(screenshots_dir) unless Dir.exist?(screenshots_dir)

        # Create simple text-based "screenshots" as examples
        sample_files = [
          {
            name: "ruby_performance.txt",
            content: <<~CONTENT
              # Ruby Performance Optimization

              ## Key Metrics:
              - Memory usage: 45% reduction
              - GC time: 30% improvement#{"  "}
              - Response time: 22% faster

              ## Before vs After:
              Before: 250ms average response
              After:  195ms average response

              Benchmark results show significant gains!
            CONTENT
          },
          {
            name: "frozen_strings_demo.txt",
            content: <<~CONTENT
              # Frozen String Literals Demo

              ## Code Example:
              ```ruby
              # frozen_string_literal: true

              def process_data(input)
                header = "Processing: "
                puts header + input
              end
              ```

              ## Result:
              ✅ No string allocations for header
              ✅ 34% performance improvement
              ✅ Reduced GC pressure
            CONTENT
          }
        ]

        sample_files.each do |file|
          file_path = File.join(screenshots_dir, file[:name])
          File.write(file_path, file[:content])
        end

        screenshots_dir
      end

      private

      def command_available?(command)
        system("which #{command} > /dev/null 2>&1")
      end

      def detect_best_viewer
        # Prefer viu for terminal display, then GUI viewers
        preferred_order = %i[viu feh sxiv fim]
        preferred_order.find { |viewer| available_viewers.key?(viewer) }
      end
    end
  end
end
