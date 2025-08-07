#!/usr/bin/env ruby
# frozen_string_literal: false

# Taiwan Flag Waving Animation 🇹🇼
# A celebration of Ruby and Taiwan using frozen strings for performance!

# All strings are frozen for maximum performance! ❄️
# Taiwan flag ASCII art lines (frozen for performance!)
TAIWAN_FLAG = [
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀".freeze,
  "⠀⠀⠀⠀⠀⠀⢸⣷⣄⠀⠀⢀⣿⣿⡀⠀⠀⣠⣾⡇⠀⠀⠀⠀⠀⠀".freeze,
  "⠀⠀⠀⠀⠀⠀⠀⣿⣿⣷⣄⡸⠿⠿⠇⣠⣾⣿⣿⠀⠀⠀⠀⠀⠀⠀".freeze,
  "⠀⠀⢶⣶⣤⣤⣀⡸⠟⠉⣀⣤⣤⣤⣤⣀⠉⠻⢇⣀⣤⣤⣶⡶⠀⠀".freeze,
  "⠀⠀⠀⠙⢿⣿⡿⠁⣴⣿⣿⣿⣿⣿⣿⣿⣿⣦⠈⢻⣿⡿⠋⠀⠀⠀".freeze,
  "⠀⠀⠀⢀⣀⣹⠁⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠈⣏⣀⣀⠀⠀⠀".freeze,
  "⠰⠶⣿⣿⣿⣿⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⣸⣿⣿⣿⠶⠆".freeze,
  "⠀⠀⠀⠈⠉⣹⡄⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⢀⣏⠉⠉⠀⠀⠀".freeze,
  "⠀⠀⠀⣠⣾⣿⣷⣄⠙⢿⣿⣿⣿⣿⣿⣿⡿⠋⣠⣾⣿⣷⣄⠀⠀⠀".freeze,
  "⠀⠀⠾⠿⠛⠛⠉⢹⣷⣄⣀⡉⠉⠉⠉⣀⣠⣾⡏⠉⠛⠛⠿⠷⠀⠀".freeze,
  "⠀⠀⠀⠀⠀⠀⠀⣿⣿⡿⠋⢹⣿⣿⡏⠙⢿⣿⣿⠀⠀⠀⠀⠀⠀⠀".freeze,
  "⠀⠀⠀⠀⠀⠀⢸⡿⠋⠀⠀⠈⣿⣿⠁⠀⠀⠙⢿⡇⠀⠀⠀⠀⠀⠀".freeze,
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀".freeze
].freeze

FLAG_POLE = "".freeze
COLORS = {
  # Taiwan flag colors
  blue_bg: "\e[44m".freeze, # Blue background only
  white_text: "\e[1;97m".freeze, # Bold bright white text (more prominent)
  white_bg: "\e[107m".freeze, # Bright white background
  blue_bg_space: "\e[44m \e[0m".freeze, # Blue background with space
  red: "\e[91m".freeze,         # Red text
  white: "\e[97m".freeze,       # White text
  blue: "\e[94m".freeze,        # Blue text
  yellow: "\e[93m".freeze,
  gray: "\e[90m".freeze,
  reset: "\e[0m".freeze
}.freeze

# Run the Taiwan flag waving animation
def run_taiwan_flag
  pole_x = 3
  flag_lines = TAIWAN_FLAG.length

  # Animate the beautiful Taiwan flag!
  40.times do |frame|
    system("clear") || system("cls")

    puts "\n#{COLORS[:red]}Taiwan Flag Fluttering in Ruby Wind#{COLORS[:reset]}"
    puts "#{COLORS[:white]}Using frozen strings for maximum performance! ❄️#{COLORS[:reset]}\n"

    # Draw the flag pole and flag
    flag_lines.times do |y|
      # Flag pole
      print "#{" " * pole_x}#{COLORS[:gray]}#{FLAG_POLE}#{COLORS[:reset]}"

      # Get the flag line
      flag_line = TAIWAN_FLAG[y]

      # Apply flutter effect to each character
      flutter_line = ""
      flag_line.each_char.with_index do |char, x|
        # Calculate flutter effect using sine waves
        horizontal_wave = Math.sin((x * 0.2) + (frame * 0.3)) * 1.5
        vertical_flutter = Math.sin((y * 0.3) + (frame * 0.25) + (x * 0.1)) * 0.8

        # Combine wave effects
        total_flutter = horizontal_wave + vertical_flutter

        # Apply flutter by occasionally shifting characters or adding slight distortion
        flutter_line += if total_flutter > 1.2
                          # Strong flutter - add slight distortion
                          if char == "⠀"
                            # Space character - normal
                            char
                          else # Visible character - bold white text
                            "#{COLORS[:white_text]}#{char}#{COLORS[:reset]}"
                          end
                        elsif total_flutter < -1.0
                          # Reverse flutter - slightly compress
                          if char != "⠀" && x.even? # Visible character
                            "#{COLORS[:white_text]}#{char}#{COLORS[:reset]}"
                          else
                            char
                          end
                        elsif char != "⠀"
                          # Normal display - bold white text for visible characters only
                          "#{COLORS[:white_text]}#{char}#{COLORS[:reset]}" # Visible character - bold bright white
                        else
                          # Space character - keep as is
                          char
                        end
      end

      puts flutter_line
    end

    # Add pole base and message
    puts "#{" " * pole_x}#{COLORS[:gray]}#{FLAG_POLE}#{COLORS[:reset]}"
    puts "#{COLORS[:gray]}#{"─" * (pole_x + 1)}┴#{"─" * 30}#{COLORS[:reset]}"

    puts "\n#{COLORS[:red]}Ruby#{COLORS[:reset]} + #{COLORS[:blue]}Taiwan#{COLORS[:reset]} = Beautiful Code Forever!"
    puts "#{COLORS[:white]}❄️  All #{TAIWAN_FLAG.length} flag lines frozen for performance!#{COLORS[:reset]}"

    sleep(0.08)
  end

  # Final message
  puts "\n#{COLORS[:yellow]}Thank you RubyConf Taiwan! 謝謝！#{COLORS[:reset]}"
  puts "#{COLORS[:blue]}Press any key to continue...#{COLORS[:reset]}"
end

# If running this file directly, show the animation
if __FILE__ == $PROGRAM_NAME
  puts "#{COLORS[:red]}█#{COLORS[:white]}█#{COLORS[:blue]}█#{COLORS[:reset]} Taiwan Flag Waving Demo #{COLORS[:red]}█#{COLORS[:white]}█#{COLORS[:blue]}█#{COLORS[:reset]}"
  puts "#{COLORS[:white]}Using frozen strings for maximum performance!#{COLORS[:reset]}"
  puts "\nPress ENTER to start the animation..."
  gets

  run_taiwan_flag

  # Wait for keypress
  begin
    require "io/console"
    $stdin.getch
  rescue StandardError
    gets
  end

  system("clear") || system("cls")
  puts "#{COLORS[:yellow]}Thanks for watching! 謝謝！#{COLORS[:reset]}"
end
