module ISpeaker
class NotesViewer
  def initialize(port = 9000)
    @port = port
    @server_uri = "druby://localhost:#{port}"
    @client_uri = nil
    @server = nil
    @running = true
  end

  def start
    puts "🔗 Starting DRuby client...".cyan
    
    # Start DRuby client
    DRb.start_service
    @client_uri = DRb.uri
    puts "✅ DRuby client started with URI: #{@client_uri}".green

    # Connect to presentation server
    puts "🌐 Connecting to presentation server at #{@server_uri}...".cyan
    @server = DRbObject.new_with_uri(@server_uri)

    # Test connection
    puts "🧪 Testing connection...".cyan
    begin
      @server.get_current_state
      puts "✅ Connection successful!".green
    rescue => e
      puts "❌ Connection test failed: #{e.message}".red
      raise e
    end

    # Get initial state
    display_notes(@server.get_current_state)

    # Keep running and poll for updates
    puts "\n📝 Connected to presentation. Press Ctrl+C to exit.".light_black

    # Handle Ctrl+C gracefully
    trap("INT") do
      @running = false
      cleanup
      exit(0)
    end

    # Poll for updates every 0.2 seconds
    last_slide_index = -1
    while @running
      begin
        current_state = @server.get_current_state
        if current_state[:slide_index] != last_slide_index
          display_notes(current_state)
          last_slide_index = current_state[:slide_index]
        end
        sleep(0.2)
      rescue StandardError => e
        puts "⚠️ Connection lost: #{e.message}".red
        break
      end
    end
  rescue DRb::DRbConnError
    puts "❌ Could not connect to presentation server on port #{@port}".red
    puts "   Make sure the main presentation is running with notes server enabled.".yellow
    puts "   Usage: i_speaker_notes [port]".light_black
    exit(1)
  end


  private

  def display_notes(state)
    system("clear") || system("cls")

    # Header
    puts "═" * 80
    puts "📝 Speaker Notes - #{state[:talk_title]}".bold.cyan
    puts "Slide #{state[:slide_number]} of #{state[:total_slides]}".light_black
    puts "═" * 80

    # Current slide title
    puts "\n#{state[:slide_title]}".bold.green
    puts "─" * state[:slide_title].length

    # Slide content preview (condensed)
    if state[:slide_content].any?
      puts "\n📊 Slide Content:".blue
      state[:slide_content].first(3).each do |item|
        # Truncate long content
        display_item = item.length > 70 ? "#{item[0..67]}..." : item
        puts "  • #{display_item}".light_white
      end
      puts "  • ..." if state[:slide_content].length > 3
    end

    # Speaker notes
    puts "\n💡 Speaker Notes:".bold.yellow
    puts "─" * 20

    if state[:slide_notes].nil? || state[:slide_notes].strip.empty?
      puts "\n(No speaker notes for this slide)".light_black.italic
      puts "\nTip: Add notes to help guide your presentation!".light_black
    else
      # Format notes with word wrapping
      puts "\n"
      format_notes(state[:slide_notes]).each do |line|
        puts line.light_white
      end
    end

    # Footer with tips
    puts "\n" + ("─" * 80)
    puts "💡 Tips:".light_blue
    puts "  • Keep eye contact with audience, glance here for reminders"
    puts "  • Notes are automatically synchronized with main presentation"
    puts "  • Press Ctrl+C to close this viewer"
  end

  def format_notes(notes)
    # Word wrap at 78 characters
    words = notes.split(" ")
    lines = []
    current_line = ""

    words.each do |word|
      if (current_line + word).length > 78
        lines << current_line.strip
        current_line = word + " "
      else
        current_line += word + " "
      end
    end

    lines << current_line.strip unless current_line.empty?
    lines
  end

  def cleanup
    DRb.stop_service
  rescue StandardError
    # Ignore errors during cleanup
  end
end
end