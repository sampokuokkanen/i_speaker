#!/usr/bin/env ruby
# frozen_string_literal: true

require "rqrcode"

# X account URL
x_url = "https://x.com/KuokkanenSampo"

puts "Generating QR code for: #{x_url}"

# Create QR code
qrcode = RQRCode::QRCode.new(x_url)

# Generate PNG
png = qrcode.as_png(
  size: 300,           # Total size of PNG in pixels
  border_modules: 4,   # White border around the modules
  color: "black",      # Foreground color
  fill: "white"        # Background color
)

# Save to file
output_file = "qr_code_x_account.png"
File.binwrite(output_file, png.to_s)

puts "QR code saved as: #{output_file}"
puts "Image size: 300x300 pixels"
puts "Ready to use in your presentation!"
