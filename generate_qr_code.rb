#!/usr/bin/env ruby
# frozen_string_literal: true

require "rqrcode"

# GitHub repository URL
github_url = "https://github.com/sampokuokkanen/i_speaker"

puts "Generating QR code for: #{github_url}"

# Create QR code
qrcode = RQRCode::QRCode.new(github_url)

# Generate PNG
png = qrcode.as_png(
  size: 300,           # Total size of PNG in pixels
  border_modules: 4,   # White border around the modules
  color: "black",      # Foreground color
  fill: "white"        # Background color
)

# Save to file
output_file = "qr_code_github_i_speaker.png"
File.binwrite(output_file, png.to_s)

puts "QR code saved as: #{output_file}"
puts "Image size: 300x300 pixels"
puts "Ready to use in your presentation!"
