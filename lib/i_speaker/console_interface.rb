# frozen_string_literal: true

require "async"
require "tty-prompt"
require "tty-spinner"
require "colorize"
require "io/console"
require "benchmark"
require_relative "ollama_client"
require_relative "zai_client"
require_relative "web_content_fetcher"
require_relative "serper_client"
require_relative "image_viewer"
require_relative "syntax_highlighter"
require_relative "presentation_server"
require_relative "ascii_art"

begin
  require "ruby_llm"
rescue LoadError
  # RubyLLM not available - will try Ollama if available
end

module ISpeaker
  class ConsoleInterface
    def initialize
      @prompt = TTY::Prompt.new
      @talk = nil
      @ai_client = nil
      @ai_available = false
      @serper_client = SerperClient.new
      @current_filename = nil
      @commentary_cache = {}
      @commentary_threads = {}
      @commentary_ready = false
      @presentation_server = PresentationServer.new
      @reactor = nil
      setup_ai
      check_serper_setup
    end

    def start
      display_welcome

      # Set up signal handlers for graceful exit with auto-save
      setup_exit_handlers

      loop do
        if @talk.nil?
          create_or_load_talk
        else
          main_menu
        end
      end
    rescue Interrupt
      handle_exit
    end

    private

    def setup_exit_handlers
      # Handle Ctrl+C gracefully
      Signal.trap("INT") do
        handle_exit
      end

      # Handle Ctrl+D (EOF) gracefully
      Signal.trap("TERM") do
        handle_exit
      end
    end

    def handle_exit
      puts "\nGoodbye! 👋".green
      exit(0)
    end

    def setup_ai
      # First priority: Z AI
      zai_client = ZAIClient.new
      if zai_client.available?
        @ai_client = zai_client
        @ai_available = true
        puts "✅ Z AI connected (GLM-4.5)".green
        return
      end

      # Second priority: Ollama (local AI)
      ollama_client = OllamaClient.new
      if ollama_client.available?
        @ai_client = ollama_client
        @ai_available = true
        puts "✅ Ollama AI connected (local)".green
        return
      end

      # Fallback to RubyLLM if available and configured
      if defined?(RubyLLM)
        begin
          RubyLLM.chat.ask("Hello")
          @ai_client = :ruby_llm
          @ai_available = true
          puts "✅ RubyLLM AI connected".green
        rescue RubyLLM::ConfigurationError => e
          puts "⚠️  RubyLLM not configured: #{e.message}".yellow
        rescue StandardError => e
          puts "⚠️  RubyLLM error: #{e.message}".yellow
        end
      end

      return if @ai_available

      puts "ℹ️  AI features disabled. To enable:".white
      puts "   - Set ZAI_API_KEY environment variable (preferred)".white
      puts "   - Or make sure Ollama is running: ollama serve".white
      puts "   - Or configure RubyLLM with API keys".white
    end

    def ai_ask(prompt, system: nil)
      return nil unless @ai_available

      case @ai_client
      when OllamaClient, ZAIClient
        @ai_client.ask(prompt, system: system)
      when :ruby_llm
        if system
          # For RubyLLM, we need to include system message in the prompt
          RubyLLM.chat.ask("#{system}\n\n#{prompt}")
        else
          RubyLLM.chat.ask(prompt)
        end
      else
        raise "Unknown AI client: #{@ai_client}"
      end
    end

    def check_serper_setup
      if @serper_client.available?
        puts "✅ Fact-checking enabled (Serper API connected)".green
      else
        puts "ℹ️  Fact-checking features disabled. Serper API key not found.".white
        puts "   You can enable fact-checking by setting SERPER_KEY environment variable".white
        puts "   Get a free key at: https://serper.dev".white
        # No longer prompt here - only prompt when actually trying to use fact-checking
      end
    end

    def setup_serper_key
      puts "\n🔑 Serper API Setup".cyan.bold
      puts "Serper provides Google search API for fact-checking your slides.".white
      puts "Get a free API key at: https://serper.dev".white

      api_key = @prompt.mask("Enter your Serper API key:")

      if api_key && !api_key.empty?
        ENV["SERPER_KEY"] = api_key
        @serper_client = SerperClient.new

        if @serper_client.available?
          puts "✅ Serper API key configured successfully!".green
          puts "Fact-checking features are now available.".white
        else
          puts "❌ Invalid API key. Please check and try again.".red
        end
      else
        puts "⚠️  No API key provided. Fact-checking features disabled.".yellow
      end
    end

    def ai_ask_with_spinner(prompt, system: nil, message: "Thinking...")
      return nil unless @ai_available

      spinner = TTY::Spinner.new("[:spinner] #{message}", format: :dots)
      spinner.auto_spin

      begin
        result = ai_ask(prompt, system: system)
        spinner.success("✅")
        result
      rescue StandardError => e
        spinner.error("❌")
        raise e
      end
    end

    def auto_save
      return unless @talk

      # Generate filename if we don't have one
      if @current_filename.nil?
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        safe_title = @talk.title.downcase.gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_").chomp("_")
        safe_title = "untitled" if safe_title.empty?
        @current_filename = "#{safe_title}_#{timestamp}.json"
        # Don't print auto-save message for performance
      end

      begin
        @talk.save_to_file(@current_filename)
        # Skip commentary cache save for performance
        # save_commentary_cache
      rescue StandardError => e
        puts "\n⚠️  Auto-save failed: #{e.message}".yellow
      end
    end

    def display_welcome
      puts <<~WELCOME.cyan

        ╔═══════════════════════════════════════╗
        ║           🎤 i_speaker 🎤            ║
        ║    AI-Powered Talk Creation Tool      ║
        ╚═══════════════════════════════════════╝

        Create compelling presentations slide by slide
        with AI assistance and proven templates.

      WELCOME
    end

    def create_or_load_talk
      options = [
        { name: "Create a new talk", value: :new },
        { name: "Create complete talk with AI#{" (unavailable)" unless @ai_available}", value: :ai_complete,
          disabled: !@ai_available },
        { name: "Load existing talk", value: :load },
        { name: "View sample talks", value: :samples },
        { name: "Exit", value: :exit },
      ]

      choice = @prompt.select("What would you like to do?", options)

      case choice
      when :new
        create_new_talk
      when :ai_complete
        create_complete_talk_with_ai
      when :load
        load_talk
      when :samples
        view_sample_talks
      when :exit
        puts "Goodbye! 👋".green
        exit(0)
      end
    end

    def create_new_talk
      puts "\n📝 Let's create your talk!".green

      title = @prompt.ask("What's the title of your talk?") do |q|
        q.required(true)
        q.modify(:strip)
      end

      description = @prompt.multiline("Describe your talk (what's it about, key messages, etc.):") do |q|
        q.required(true)
      end.join("\n")

      audience = @prompt.ask("Who's your target audience? (optional):", default: "General audience")

      duration = @prompt.ask("How long should the talk be? (minutes):", default: 30) do |q|
        q.convert(:int)
      end

      @talk = Talk.new(
        title: title,
        description: description,
        target_audience: audience,
        duration_minutes: duration,
      )

      puts "\n✅ Talk created successfully!".green
      puts @talk.summary.white

      # Auto-save after creating talk
      auto_save

      return unless @ai_available && @prompt.yes?("\nWould you like AI help creating your first slide?")

      create_ai_slide
    end

    def create_complete_talk_with_ai
      puts "\n🤖 Let's create a complete talk with AI assistance!".green
      puts "I'll guide you through the process step by step.\n".white

      # Get the title
      title = @prompt.ask("What's the title of your talk?") do |q|
        q.required(true)
        q.modify(:strip)
      end

      # Get initial description - more detailed for AI
      puts "\n📝 Now let's describe your talk in detail...".yellow
      puts "This description helps the AI understand your goals and create better content.".white

      description = @prompt.multiline("Describe your talk (what's it about, key messages, main goals, etc.):") do |q|
        q.required(true)
      end.join("\n")

      # Get additional context for AI processing
      puts "\n🎯 Let's gather more specific context for the AI...".yellow

      topic_context = @prompt.multiline("Any additional context, specific topics, or requirements? (Press Enter twice when done, or leave blank)") do |q|
        q.required(false)
      end.join("\n")

      # Use description as primary context, with additional context if provided
      full_context = description
      full_context + "\n\nAdditional context: #{topic_context}" unless topic_context.strip.empty?

      audience = @prompt.ask("Who's your target audience?", default: "General audience")

      duration = @prompt.ask("How long should the talk be? (minutes):", default: 30) do |q|
        q.convert(:int)
      end

      # Create basic talk first (so we always have @talk available)
      @talk = Talk.new(
        title: title,
        description: description,
        target_audience: audience,
        duration_minutes: duration,
      )

      # AI will ask clarifying questions
      puts "\n🤔 Let me ask you a few questions to better understand your talk...".yellow

      begin
        # Generate clarifying questions
        questions_prompt = <<~PROMPT
          You're helping create a presentation titled "#{title}".
          Description: #{description}
          #{"Additional context: #{topic_context}" unless topic_context.strip.empty?}
          Audience: #{audience}
          Duration: #{duration} minutes

          Generate 3-5 clarifying questions that would help create a better, more focused presentation.
          Questions should be specific and help understand:
          - Key messages and takeaways
          - Specific examples or case studies
          - Level of technical detail needed
          - Desired outcomes for the audience

          Format as numbered questions, one per line.
        PROMPT

        response = ai_ask_with_spinner(questions_prompt, message: "Generating clarifying questions...")
        questions = response.strip.split("\n").grep(/^\d+\./)

        answers = {}
        questions.each do |question|
          answer = @prompt.multiline("#{question} (Press Enter twice when done)") do |q|
            q.required(true)
          end.join("\n")
          answers[question] = answer
        end

        # Create the talk structure
        puts "\n🏗️  Creating talk structure...".yellow

        structure_prompt = <<~PROMPT
          Create a detailed talk structure for:
          Title: #{title}
          Description: #{description}
          #{"Additional context: #{topic_context}" unless topic_context.strip.empty?}
          Audience: #{audience}
          Duration: #{duration} minutes

          Additional context from Q&A:
          #{answers.map { |q, a| "Q: #{q}\nA: #{a}" }.join("\n\n")}

          Create:
          1. A compelling description (2-3 sentences)
          2. The optimal number of slides for a #{duration}-minute talk
          3. A title for each slide
          4. 3-4 key points for each slide
          5. Speaker notes with examples and transitions

          IMPORTANT: Respond ONLY with valid JSON in exactly this format (no extra text before or after):
          {
            "description": "compelling description here",
            "slides": [
              {
                "title": "slide title here",
                "content": ["point 1", "point 2", "point 3"],
                "speaker_notes": "detailed speaker notes here"
              }
            ]
          }
        PROMPT

        json_response = ai_ask_with_spinner(structure_prompt, message: "Creating detailed talk structure...")

        # Parse JSON response more robustly
        require "json"

        # Try to extract JSON from the response (AI might include extra text)
        json_content = nil
        if json_response.include?("{") && json_response.include?("}")
          # Find the first complete JSON object in the response
          start_index = json_response.index("{")
          bracket_count = 0
          end_index = start_index

          json_response[start_index..].each_char.with_index(start_index) do |char, i|
            bracket_count += 1 if char == "{"
            bracket_count -= 1 if char == "}"
            if bracket_count.zero?
              end_index = i
              break
            end
          end

          json_content = json_response[start_index..end_index]
        end

        talk_structure = JSON.parse(json_content || "{}")

        # Update the talk with AI-generated description if available
        if talk_structure["description"] && !talk_structure["description"].empty?
          @talk.description = talk_structure["description"]
        end

        # Show preview and get confirmation
        puts "\n📋 Here's the proposed talk structure:".white
        puts "\n#{@talk.title.bold}"
        puts @talk.description

        slides = talk_structure["slides"] || []
        if slides.any?
          puts "\nSlides (#{slides.length} total):".bold

          slides.each_with_index do |slide_data, index|
            puts "\n#{index + 1}. #{slide_data["title"] || "Slide #{index + 1}"}"
            content = slide_data["content"] || []
            content.each { |point| puts "   • #{point}" }
          end

          if @prompt.yes?("\n✨ Would you like me to create this talk with all slides?")
            # Create all slides
            slides.each_with_index do |slide_data, index|
              slide = Slide.new(
                title: slide_data["title"] || "Slide #{index + 1}",
                content: slide_data["content"] || ["Content for slide #{index + 1}"],
                notes: slide_data["speaker_notes"] || "Speaker notes for slide #{index + 1}"
              )
              @talk.add_slide(slide)
              puts "✅ Created slide #{index + 1}: #{slide.title}".green
            end

            puts "\n🎉 Complete talk created successfully!".green.bold
            puts "Total slides: #{@talk.slides.length}".white

            # Auto-save after creating complete talk
            auto_save

            puts "\nYou can now edit individual slides, reorder them, or export your talk.".white
          else
            puts "\nNo problem! The talk has been created without slides.".yellow
            puts "You can add slides manually or use AI assistance from the main menu.".white
          end
        else
          puts "\nAI couldn't generate slides automatically, but the talk structure is ready.".yellow
          puts "You can add slides manually or use AI assistance from the main menu.".white
        end
      rescue JSON::ParserError
        puts "\n❌ AI response wasn't in expected JSON format. Using simpler approach.".red
        puts "✅ Basic talk structure created successfully!".green
        auto_save  # Save what we have
        puts @talk.summary.white
        puts "\n💡 You can now add slides manually or use individual AI assistance from the main menu.".white
      rescue StandardError => e
        puts "\n❌ Error with AI generation: #{e.message}".red
        puts "✅ Basic talk structure created successfully!".green
        auto_save  # Save what we have
        puts @talk.summary.white
        puts "\n💡 You can now add slides manually or use individual AI assistance from the main menu.".white
      end
    end

    def load_talk
      # Find all JSON files in the current directory, excluding commentary files
      json_files = Dir.glob("*.json")
                      .reject { |f| f.end_with?("_commentary.json") }
                      .sort_by { |f| File.mtime(f) }.reverse

      if json_files.empty?
        puts "\n📁 No talk files found in current directory.".yellow
        puts "   Create a new talk or make sure you're in the right directory.".white
        return
      end

      puts "\n📁 Available talk files (most recent first):".white

      # Display files with preview info
      file_options = []
      json_files.each_with_index do |filename, _index|
        # Try to get basic info about the talk
        data = JSON.parse(File.read(filename), symbolize_names: true)
        title = data[:title] || "Untitled"
        slide_count = data[:slides]&.length || 0
        duration = data[:duration_minutes] || "Unknown"
        modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")

        display_name = "#{filename} - \"#{title}\" (#{slide_count} slides, #{duration}min) [#{modified_time}]"
        file_options << { name: display_name, value: filename }
      rescue StandardError
        # If we can't parse the file, still show it but with warning
        modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")
        display_name = "#{filename} - ⚠️  Invalid JSON format [#{modified_time}]"
        file_options << { name: display_name, value: filename }
      end

      # Add additional options
      file_options << { name: "📝 Enter filename manually", value: :manual }
      file_options << { name: "📂 Browse other directories", value: :browse }
      file_options << { name: "🔙 Back to main menu", value: :back }

      choice = @prompt.select("Select a talk file to load:", file_options)

      case choice
      when :manual
        filename = @prompt.ask("Enter the filename to load (with .json extension):")
        load_talk_file(filename)
      when :browse
        browse_and_load_talk
      when :back
        nil
      else
        load_talk_file(choice)
      end
    end

    def load_talk_file(filename)
      if File.exist?(filename)
        begin
          @talk = Talk.load_from_file(filename)
          @current_filename = filename # Set current filename for auto-save
          load_commentary_cache # Load cached commentary
          puts "\n✅ Talk loaded successfully!".green
          puts @talk.summary.white
        rescue StandardError => e
          puts "\n❌ Error loading talk: #{e.message}".red
          puts "   Make sure the file is a valid i_speaker JSON file.".yellow
        end
      else
        puts "❌ File not found: #{filename}".red
      end
    end

    def browse_and_load_talk
      path = @prompt.ask("Enter the directory path to browse:", default: ".")

      unless Dir.exist?(path)
        puts "❌ Directory not found: #{path}".red
        return
      end

      # Find JSON files in the specified directory
      json_files = Dir.glob(File.join(path, "*.json")).sort_by { |f| File.mtime(f) }.reverse

      if json_files.empty?
        puts "\n📁 No JSON files found in #{path}".yellow
        return
      end

      puts "\n📁 JSON files in #{File.expand_path(path)} (most recent first):".white

      file_options = []
      json_files.each do |full_path|
        filename = File.basename(full_path)
        begin
          # Try to get basic info about the talk
          data = JSON.parse(File.read(full_path), symbolize_names: true)
          title = data[:title] || "Untitled"
          slide_count = data[:slides]&.length || 0
          duration = data[:duration_minutes] || "Unknown"
          modified_time = File.mtime(full_path).strftime("%Y-%m-%d %H:%M")

          display_name = "#{filename} - \"#{title}\" (#{slide_count} slides, #{duration}min) [#{modified_time}]"
          file_options << { name: display_name, value: full_path }
        rescue StandardError
          # If we can't parse the file, still show it but with warning
          modified_time = File.mtime(full_path).strftime("%Y-%m-%d %H:%M")
          display_name = "#{filename} - ⚠️  Invalid JSON format [#{modified_time}]"
          file_options << { name: display_name, value: full_path }
        end
      end

      file_options << { name: "🔙 Back to load menu", value: :back }

      choice = @prompt.select("Select a file to load:", file_options)

      return unless choice != :back

      load_talk_file(choice)
    end

    def view_sample_talks
      puts "\n📚 Sample Talks:".white

      SampleTalks.all.each_with_index do |talk, index|
        puts "\n#{index + 1}. #{talk[:title].bold}"
        puts "   #{talk[:description]}"
        puts "   Slides: #{talk[:slides].length}"
      end

      return unless @prompt.yes?("\nWould you like to see details of a specific sample?")

      choice = @prompt.select(
        "Which sample would you like to explore?",
        SampleTalks.all.map.with_index { |talk, i| { name: talk[:title], value: i } },
      )

      show_sample_talk_details(SampleTalks.all[choice])
    end

    def show_sample_talk_details(sample_talk)
      puts "\n#{sample_talk[:title].bold.white}"
      puts sample_talk[:description]
      puts "\nSlides:".bold

      sample_talk[:slides].each_with_index do |slide, index|
        puts "\n#{index + 1}. #{slide[:title].bold}"
        slide[:content].each { |point| puts "   • #{point}" }
      end

      @prompt.keypress("\nPress any key to continue...")
    end

    def main_menu
      current_file_info = @current_filename ? " [#{@current_filename}]" : " [auto-saved]"

      choice = @prompt.select("#{"\n🎤 #{@talk.title}#{current_file_info}".bold} - What would you like to do?", [
                                { name: "View talk overview", value: :overview },
                                { name: "🎬 Present slideshow", value: :retro_slideshow },
                                { name: "📝 Present with notes server", value: :present_with_notes },
                                { name: "Create new slide", value: :new_slide },
                                { name: "📷 Create image slide", value: :new_image_slide },
                                { name: "Edit existing slide", value: :edit_slide },
                                { name: "Reorder slides", value: :reorder },
                                { name: "Delete slide", value: :delete_slide },
                                { name: "AI assistance", value: :ai_help },
                                { name: "Export talk", value: :export },
                                { name: "Start over (new talk)", value: :new_talk },
                                { name: "Exit", value: :exit },
                              ])

      case choice
      when :overview
        show_talk_overview
      when :retro_slideshow
        retro_slideshow
      when :present_with_notes
        present_with_notes_server
      when :new_slide
        create_new_slide
      when :new_image_slide
        create_new_image_slide
      when :edit_slide
        edit_slide_menu
      when :reorder
        reorder_slides
      when :delete_slide
        delete_slide
      when :ai_help
        ai_assistance_menu
      when :export
        export_talk
      when :new_talk
        @talk = nil
        @current_filename = nil # Reset filename for new talk
      when :exit
        puts "Goodbye! 👋".green
        exit(0)
      end
    end

    def show_talk_overview
      puts "\n#{@talk.summary.white}"

      if @talk.slides.any? && @prompt.yes?("\nWould you like to see detailed slide content?")
        @talk.slides.each_with_index do |slide, index|
          puts "\n#{"─" * 50}"
          puts "Slide #{index + 1}:".bold
          puts slide
        end
      end

      @prompt.keypress("\nPress any key to continue...")
    end

    def retro_slideshow
      if @talk.slides.empty?
        puts "\n⚠️  No slides to display!".yellow
        @prompt.keypress("Press any key to continue...")
        return
      end

      # Ask if they want AI commentary
      use_commentary = false
      if @ai_available
        puts "\n🎭 Would you like live AI commentary during the slideshow?".white
        puts "   The AI will generate witty remarks and dad jokes about each slide!".white
        use_commentary = @prompt.yes?("Enable AI Comedy Commentary?")
      end

      current_slide_index = 0
      start_time = Time.now
      timer_paused = false
      pause_start_time = nil
      total_pause_duration = 0

      puts "\n🎬 Starting presentation#{" with AI commentary" if use_commentary}...".white
      puts "Navigation: SPACE/→ = Next | ← = Previous | ENTER = IRB Demo | C = Commentary | P = Pause/Resume | ESC = Exit".light_black
      puts "Tip: Images will prompt ENTER to view | IRB slides launch interactive Ruby | Timer shows elapsed time".light_black
      # Removed sleep for faster start

      loop do
        # Preload commentary for nearby slides
        preload_commentary_for_slides(@talk.slides, current_slide_index) if use_commentary

        # Calculate elapsed time
        current_pause_duration = if timer_paused && pause_start_time
                                   Time.now - pause_start_time
                                 else
                                   0
                                 end

        elapsed_seconds = (Time.now - start_time - total_pause_duration - current_pause_duration).to_i

        system("clear") || system("cls")
        display_retro_slide(current_slide_index,
                            show_commentary: use_commentary,
                            elapsed_time: elapsed_seconds,
                            timer_paused: timer_paused,
                            total_slides: @talk.slides.length)

        # Get single keypress without showing menu
        # Check if image slide returned a navigation key
        key = @last_key || get_single_keypress
        @last_key = nil

        case key
        when :left
          current_slide_index -= 1 if current_slide_index.positive?
        when :right, :space
          current_slide_index += 1 if current_slide_index < @talk.slides.length - 1
          # Stay on last slide instead of exiting
        when :enter
          # Check if current slide is an IRB demo slide
          current_slide = @talk.slides[current_slide_index]
          launch_irb_for_slide(current_slide) if is_irb_slide?(current_slide)
        when :c
          # Toggle commentary
          if @ai_available
            use_commentary = !use_commentary
            puts "\n🎭 Commentary #{use_commentary ? "ON" : "OFF"}".yellow
          end
        when :p
          # Toggle pause
          if timer_paused
            # Resume
            total_pause_duration += Time.now - pause_start_time if pause_start_time
            timer_paused = false
            pause_start_time = nil
          else
            # Pause
            timer_paused = true
            pause_start_time = Time.now
          end
        when :escape
          system("clear") || system("cls")
          break
        end
      end
    end

    def present_with_notes_server
      if @talk.slides.empty?
        puts "\n⚠️  No slides to display!".yellow
        @prompt.keypress("Press any key to continue...")
        return
      end

      # Start notes server
      port = 9000
      front_object = @presentation_server.start_server(port)

      unless front_object
        puts "Could not start notes server. Falling back to regular slideshow."
        retro_slideshow
        return
      end

      # Use the front object for all server operations
      @drb_server = front_object

      # Initialize server with talk information
      initial_slide = @talk.slides.first
      @drb_server.update_slide(0, initial_slide, @talk.slides.length, @talk.title)

      # Ask if they want AI commentary
      use_commentary = false
      if @ai_available
        puts "\n🎭 Would you like live AI commentary during the slideshow?".white
        puts "   The AI will generate witty remarks and dad jokes about each slide!".white
        use_commentary = @prompt.yes?("Enable AI Comedy Commentary?")
      end

      current_slide_index = 0
      start_time = Time.now
      timer_paused = false
      pause_start_time = nil
      total_pause_duration = 0

      puts "\n🎬 Starting presentation with notes server#{" and AI commentary" if use_commentary}...".white
      puts "Navigation: SPACE/→ = Next | ← = Previous | ENTER = IRB Demo | C = Commentary | P = Pause/Resume | ESC = Exit".light_black
      puts "📝 Run 'i_speaker_notes #{port}' in another terminal for speaker notes".yellow
      puts "Tip: Images will prompt ENTER to view | IRB slides launch interactive Ruby | Timer shows elapsed time".light_black

      # Give user time to connect notes viewer
      puts "\n⏳ Waiting for notes viewer connection...".white
      puts "   Press SPACE to start presentation now, or wait 10 seconds".light_black

      # Wait for either keypress or timeout
      start_wait = Time.now
      key_pressed = false

      while (Time.now - start_wait) < 10 && !key_pressed
        if $stdin.ready?
          key = $stdin.getch
          if key == " "
            key_pressed = true
            puts "▶️  Starting presentation...".green
          end
        end
        sleep(0.1)
      end

      puts "⏰ Auto-starting presentation...".white unless key_pressed

      begin
        loop do
          # Preload commentary for nearby slides
          preload_commentary_for_slides(@talk.slides, current_slide_index) if use_commentary

          # Calculate elapsed time
          current_pause_duration = if timer_paused && pause_start_time
                                     Time.now - pause_start_time
                                   else
                                     0
                                   end

          elapsed_seconds = (Time.now - start_time - total_pause_duration - current_pause_duration).to_i

          # Update notes server with current slide (moved to after navigation)

          system("clear") || system("cls")
          display_retro_slide(current_slide_index,
                              show_commentary: use_commentary,
                              elapsed_time: elapsed_seconds,
                              timer_paused: timer_paused,
                              total_slides: @talk.slides.length)

          # Get single keypress without showing menu, with timeout for commentary updates
          # Check if image slide returned a navigation key
          if @last_key
            key = @last_key
            @last_key = nil
          else
            # Wait for keypress or check for commentary updates every 0.5 seconds
            key = nil
            start_time = Time.now
            while key.nil? && (Time.now - start_time) < 0.5
              if $stdin.ready?
                key = get_single_keypress
              else
                sleep(0.1)
              end
            end

            # If no key pressed but commentary might be ready, refresh display
            if key.nil? && use_commentary && @commentary_ready
              @commentary_ready = false
              next # Skip to next loop iteration to refresh display
            end

            # If still no key, wait for actual keypress
            key ||= get_single_keypress
          end

          case key
          when :left
            current_slide_index -= 1 if current_slide_index.positive?
          when :right, :space
            current_slide_index += 1 if current_slide_index < @talk.slides.length - 1
            # Stay on last slide instead of exiting
          when :enter
            # Check if current slide is an IRB demo slide
            current_slide = @talk.slides[current_slide_index]
            launch_irb_for_slide(current_slide) if is_irb_slide?(current_slide)
          when :c
            # Toggle commentary
            if @ai_available
              use_commentary = !use_commentary
              puts "\n🎭 Commentary #{use_commentary ? "ON" : "OFF"}".yellow
            end
          when :p
            # Toggle pause
            if timer_paused
              # Resume
              total_pause_duration += Time.now - pause_start_time if pause_start_time
              timer_paused = false
              pause_start_time = nil
            else
              # Pause
              timer_paused = true
              pause_start_time = Time.now
            end
          when :escape
            system("clear") || system("cls")
            break
          end

          # Update notes server with current slide after any navigation
          current_slide = @talk.slides[current_slide_index]
          @drb_server.update_slide(current_slide_index, current_slide, @talk.slides.length, @talk.title)
        end
      ensure
        # Clean up notes server
        @presentation_server.stop_server
        puts "\n📝 Notes server stopped.".light_black
      end
    end

    def display_retro_slide(index, show_commentary: false, elapsed_time: 0, timer_paused: false, total_slides: nil)
      slide = @talk.slides[index]

      # Handle image slides specially
      if slide.image_slide? && slide.has_valid_image?
        display_image_slide(slide, index, show_commentary, elapsed_time, timer_paused)
        return
      end

      # Handle demo slides specially
      if slide.demo_slide? && slide.has_demo_code?
        display_demo_slide(slide, index, show_commentary, elapsed_time, timer_paused)
        return
      end

      # Get actual terminal dimensions
      terminal_height, terminal_width = get_terminal_size

      # Leave some margin for safety
      terminal_width -= 2
      terminal_height -= 3

      # Create retro border
      puts "╔#{"═" * (terminal_width - 2)}╗"

      # Timer and slide info in top bar
      timer_display = format_timer(elapsed_time, timer_paused, index, @talk.slides.length, @talk.duration_minutes)
      slide_info = "#{index + 1}/#{@talk.slides.length}"

      # Calculate spacing for top bar
      timer_length = timer_display.gsub(/\e\[[0-9;]*m/, "").length # Remove color codes for length
      slide_info_length = slide_info.length
      remaining_space = [terminal_width - 2 - timer_length - slide_info_length - 2, 0].max

      puts "║ #{timer_display}#{" " * remaining_space}#{slide_info.light_black} ║"

      # Empty line
      puts "║#{" " * (terminal_width - 2)}║"

      # Title - centered with size scaling
      title = slide.title
      title_size = terminal_width > 100 ? :large : :normal

      # Use ASCII art for short, important titles
      use_ascii_art = title_size == :large && title.length < 20 &&
                      (title.include?("DEMO") || title.include?("WELCOME") ||
                       title.include?("Q&A") || title.include?("THANK") ||
                       index.zero? || index == @talk.slides.length - 1)

      if use_ascii_art
        # Display ASCII art title
        ascii_lines = ISpeaker::AsciiArt.center_large_text(title, terminal_width - 2, :green)
        ascii_lines.each do |line|
          right_padding = [terminal_width - 2 - line.gsub(/\e\[[0-9;]*m/, "").length, 0].max
          puts "║#{line}#{" " * right_padding}║"
        end
      else
        # Regular title display
        title_display = if title_size == :large && title.length < 50
                          title.upcase
                        else
                          title
                        end
        title_style = title_display.bold.green

        # Handle long titles
        title_display = "#{title_display[0...(terminal_width - 9)]}..." if title_display.length > terminal_width - 6

        title_padding = [(terminal_width - 2 - title_display.length) / 2, 0].max
        right_padding = [terminal_width - 2 - title_padding - title_display.length, 0].max
        puts "║#{" " * title_padding}#{title_style}#{" " * right_padding}║"
      end

      # Title underline - make it proportional (skip for ASCII art)
      unless use_ascii_art
        underline_length = [title.length, terminal_width - 20].min
        underline = "─" * underline_length
        underline_padding = [(terminal_width - 2 - underline.length) / 2, 0].max
        right_padding = [terminal_width - 2 - underline_padding - underline.length, 0].max
        puts "║#{" " * underline_padding}#{underline.green}#{" " * right_padding}║"
      end

      # Empty lines - adjust based on terminal height
      empty_lines = terminal_height > 30 ? 3 : 2
      empty_lines.times { puts "║#{" " * (terminal_width - 2)}║" }

      # Content - prepare and wrap long lines, with code highlighting
      content_items = []
      max_content_width = terminal_width - 10 # Leave margin for bullets and padding

      slide.content.each do |item|
        # Check if this looks like a code block (indented or contains code patterns)
        if item == "```ruby" || item == "```"
          next
        elsif is_code_block?(item)
          # Format as code block with syntax highlighting - keep as single block
          highlighted_code = SyntaxHighlighter.format_code_block(item.strip)
          content_items << { type: :code_block, content: highlighted_code }
        elsif item.length > max_content_width - 2
          # Regular text content with bullet point
          wrapped_items = wrap_text("• #{item}", max_content_width)
          wrapped_items.each { |line| content_items << { type: :text, content: line } }
        else
          content_items << { type: :text, content: "• #{item}" }
        end
      end

      # Calculate vertical padding for full screen usage
      empty_lines = terminal_height > 30 ? 3 : 2
      header_lines = 5 + empty_lines # top border, timer bar, empty line, title, underline, empty lines
      footer_lines = 3 # bottom border, empty line, nav hint
      available_height = terminal_height - header_lines - footer_lines

      # Calculate total content height including code blocks
      total_content_lines = 0
      content_items.each do |item|
        total_content_lines += if item[:type] == :code_block
                                 item[:content].split("\n").length
                               else
                                 1
                               end
      end

      # Calculate content area with spacing between items
      content_height = content_items.empty? ? 0 : (total_content_lines + (content_items.length - 1))
      remaining_lines = available_height - content_height
      top_padding = [remaining_lines / 2, 0].max
      bottom_padding = [remaining_lines - top_padding, 0].max

      # Add top padding
      top_padding.times { puts "║#{" " * (terminal_width - 2)}║" }

      # Display content with proper handling for code blocks
      content_items.each_with_index do |item, idx|
        if item[:type] == :code_block
          # Display code block as a unit, centered as a whole
          code_lines = item[:content].split("\n")

          # Find the widest line for centering the entire block
          max_visible_width = code_lines.map { |line| strip_ansi_codes(line).length }.max || 0
          block_padding = [(terminal_width - 2 - max_visible_width) / 2, 0].max

          code_lines.each do |line|
            visible_length = strip_ansi_codes(line).length
            # Left-align within the code block, but center the block itself
            line_padding = block_padding
            right_padding = [terminal_width - 2 - line_padding - visible_length, 0].max
            puts "║#{" " * line_padding}#{line}#{" " * right_padding}║"
          end
        else
          # Regular text content - center normally
          line = item[:content]
          visible_length = strip_ansi_codes(line).length

          if visible_length > terminal_width - 4
            line = "#{truncate_with_ansi(line, terminal_width - 7)}..."
            visible_length = strip_ansi_codes(line).length
          end

          line_padding = [(terminal_width - 2 - visible_length) / 2, 0].max
          right_padding = [terminal_width - 2 - line_padding - visible_length, 0].max
          # Make bullet points more prominent
          display_line = if line.strip.start_with?("•")
                           line.gsub(/^(\s*)•/, '\1▸').bold.white
                         elsif line.strip.start_with?("▸")
                           line.bold.white
                         else
                           line.white
                         end

          puts "║#{" " * line_padding}#{display_line}#{" " * right_padding}║"
        end

        # Add spacing between items (but not after last)
        puts "║#{" " * (terminal_width - 2)}║" if idx < content_items.length - 1
      end

      # Add bottom padding to fill screen
      bottom_padding.times { puts "║#{" " * (terminal_width - 2)}║" }

      # Bottom border
      puts "╚#{"═" * (terminal_width - 2)}╝"

      # AI Commentary section
      return unless show_commentary && @ai_available

      commentary = generate_slide_commentary(slide)
      return unless commentary && !commentary.strip.empty?

      puts "\n┌─ 🎭 AI COMEDY CORNER ─────────────────────────────────────────────────┐".yellow
      commentary_lines = wrap_text(commentary, terminal_width - 6)
      commentary_lines.each do |line|
        padded_line = line.ljust(terminal_width - 6)
        puts "│ #{padded_line.light_yellow} │".yellow
      end
      puts "└───────────────────────────────────────────────────────────────────────┘".yellow
    end

    def display_image_slide(slide, index, show_commentary, elapsed_time = 0, timer_paused = false)
      # Get actual terminal dimensions
      _, terminal_width = get_terminal_size
      terminal_width -= 2

      # Display header
      puts "╔#{"═" * (terminal_width - 2)}╗"

      # Timer and slide info in top bar
      timer_display = format_timer(elapsed_time, timer_paused, index, @talk.slides.length, @talk.duration_minutes)
      slide_info = "#{index + 1}/#{@talk.slides.length}"

      # Calculate spacing
      timer_length = timer_display.gsub(/\e\[[0-9;]*m/, "").length
      slide_info_length = slide_info.length
      remaining_space = [terminal_width - 2 - timer_length - slide_info_length - 2, 0].max

      puts "║ #{timer_display}#{" " * remaining_space}#{slide_info.light_black} ║"
      puts "║#{" " * (terminal_width - 2)}║"

      # Title
      title = slide.title
      title_padding = [(terminal_width - 2 - title.length) / 2, 0].max
      right_padding = [terminal_width - 2 - title_padding - title.length, 0].max
      puts "║#{" " * title_padding}#{title.bold.green}#{" " * right_padding}║"

      # Image indicator
      image_name = File.basename(slide.image_path)
      image_text = "📷 #{image_name}"
      image_padding = [(terminal_width - 2 - image_text.length) / 2, 0].max
      right_padding = [terminal_width - 2 - image_padding - image_text.length, 0].max
      puts "║#{" " * image_padding}#{image_text.white}#{" " * right_padding}║"

      puts "║#{" " * (terminal_width - 2)}║"

      # Content (if mixed slide)
      if slide.slide_type == :mixed && !slide.content.empty?
        slide.content.each do |item|
          bullet_line = "• #{item}"
          line_padding = [(terminal_width - 2 - bullet_line.length) / 2, 0].max
          right_padding = [terminal_width - 2 - line_padding - bullet_line.length, 0].max
          puts "║#{" " * line_padding}#{bullet_line.white}#{" " * right_padding}║"
        end
        puts "║#{" " * (terminal_width - 2)}║"
      end

      # Instructions
      instruction = "Press ENTER to view image"
      inst_padding = [(terminal_width - 2 - instruction.length) / 2, 0].max
      right_padding = [terminal_width - 2 - inst_padding - instruction.length, 0].max
      puts "║#{" " * inst_padding}#{instruction.yellow}#{" " * right_padding}║"

      puts "╚#{"═" * (terminal_width - 2)}╝"

      # AI Commentary
      if show_commentary && @ai_available
        commentary = generate_slide_commentary(slide)
        if commentary && !commentary.strip.empty?
          puts "\n┌─ 🎭 AI COMEDY CORNER ─────────────────────────────────────────────────┐".yellow
          commentary_lines = wrap_text(commentary, terminal_width - 6)
          commentary_lines.each do |line|
            padded_line = line.ljust(terminal_width - 6)
            puts "│ #{padded_line.light_yellow} │".yellow
          end
          puts "└───────────────────────────────────────────────────────────────────────┘".yellow
        end
      end

      # Navigation hint
      nav_hint = "ENTER = View Image | SPACE/→ Next | ← Previous | P Pause | ESC Exit"
      nav_padding = [(terminal_width - nav_hint.length) / 2, 0].max
      puts "\n#{" " * nav_padding}#{nav_hint.light_black}"

      # Wait for user input and potentially display image
      key = get_single_keypress
      if key == :enter
        system("clear") || system("cls")
        ImageViewer.display_image_info(slide.image_path)
        puts ""
        success = ImageViewer.display_image(slide.image_path)
        unless success
          puts "❌ Could not display image. Install viu, feh, sxiv, or fim for image support.".red
          puts "Press any key to continue...".light_black
          get_single_keypress
        end
      else
        # Return the key so the main loop can handle navigation
        @last_key = key
      end
    end

    def display_demo_slide(slide, index, show_commentary, elapsed_time = 0, timer_paused = false)
      # Get actual terminal dimensions
      _, terminal_width = get_terminal_size
      terminal_width -= 2

      # Display header
      puts "╔#{"═" * (terminal_width - 2)}╗"

      # Timer and slide info in top bar
      timer_display = format_timer(elapsed_time, timer_paused, index, @talk.slides.length, @talk.duration_minutes)
      slide_info = "#{index + 1}/#{@talk.slides.length}"

      # Calculate spacing
      timer_length = timer_display.gsub(/\e\[[0-9;]*m/, "").length
      slide_info_length = slide_info.length
      remaining_space = [terminal_width - 2 - timer_length - slide_info_length - 2, 0].max

      puts "║ #{timer_display}#{" " * remaining_space}#{slide_info.light_black} ║"
      puts "║#{" " * (terminal_width - 2)}║"

      # Title
      title = slide.title
      title_padding = [(terminal_width - 2 - title.length) / 2, 0].max
      right_padding = [terminal_width - 2 - title_padding - title.length, 0].max
      puts "║#{" " * title_padding}#{title.bold.green}#{" " * right_padding}║"

      puts "║#{" " * (terminal_width - 2)}║"

      # Demo description content (not the actual demo code)
      slide.content.each do |item|
        bullet_line = "• #{item}"
        line_padding = [(terminal_width - 2 - bullet_line.length) / 2, 0].max
        right_padding = [terminal_width - 2 - line_padding - bullet_line.length, 0].max
        puts "║#{" " * line_padding}#{bullet_line.white}#{" " * right_padding}║"
      end
      puts "║#{" " * (terminal_width - 2)}║"

      # Demo indicator
      demo_text = "🎯 Interactive Ruby Demo Ready"
      demo_padding = [(terminal_width - 2 - demo_text.length) / 2, 0].max
      right_padding = [terminal_width - 2 - demo_padding - demo_text.length, 0].max
      puts "║#{" " * demo_padding}#{demo_text.light_cyan}#{" " * right_padding}║"

      puts "║#{" " * (terminal_width - 2)}║"

      # Instructions
      instruction = "Press ENTER to run the interactive demo"
      inst_padding = [(terminal_width - 2 - instruction.length) / 2, 0].max
      right_padding = [terminal_width - 2 - inst_padding - instruction.length, 0].max
      puts "║#{" " * inst_padding}#{instruction.yellow.bold}#{" " * right_padding}║"

      puts "╚#{"═" * (terminal_width - 2)}╝"

      # AI Commentary
      if show_commentary && @ai_available
        commentary = generate_slide_commentary(slide)
        if commentary && !commentary.strip.empty?
          puts "\n┌─ 🎭 AI COMEDY CORNER ─────────────────────────────────────────────────┐".yellow
          commentary_lines = wrap_text(commentary, terminal_width - 6)
          commentary_lines.each do |line|
            padded_line = line.ljust(terminal_width - 6)
            puts "│ #{padded_line.light_yellow} │".yellow
          end
          puts "└───────────────────────────────────────────────────────────────────────┘".yellow
        end
      end

      # Navigation hint
      nav_hint = "ENTER = Run Demo | SPACE/→ Next | ← Previous | P Pause | ESC Exit"
      nav_padding = [(terminal_width - nav_hint.length) / 2, 0].max
      puts "\n#{" " * nav_padding}#{nav_hint.light_black}"

      # Wait for user input and potentially run demo
      key = get_single_keypress
      if key == :enter
        system("clear") || system("cls")
        puts "🎯 Interactive Ruby Demo Session".cyan.bold
        puts "═" * 60
        puts ""
        
        # Execute each line of demo code with REPL-style display
        execute_demo_with_repl_style(slide.demo_code)
        
        puts "\n" + "═" * 60
        puts "✅ Demo session completed! Press any key to continue...".green
        get_single_keypress
      else
        # Return the key so the main loop can handle navigation
        @last_key = key
      end
    end

    def execute_demo_with_repl_style(demo_code)
      puts "🎮 Interactive Ruby Demo - Press ENTER to execute each statement".white
      puts "─" * 60
      puts ""
      
      # Reset demo context for new demo
      @demo_context = []
      
      # Group lines into logical execution blocks
      execution_blocks = group_code_into_blocks(demo_code)
      
      execution_blocks.each do |block|
        # Display the block
        block[:lines].each do |line|
          display_line = highlight_code_line(line)
          puts "irb> #{display_line}"
        end
        
        # Always add lines to demo context (including comments)
        add_lines_to_context(block[:lines])
        
        # If it's executable, wait for ENTER and execute
        if block[:executable]
          print "Press ENTER to execute...".light_black
          gets
          print "\r" + " " * 30 + "\r"  # Clear prompt
          
          # Execute this block and show output
          result = execute_single_block(block[:lines])
          
          if result[:output] && !result[:output].strip.empty?
            result[:output].strip.split("\n").each do |line|
              puts "=> #{line}".green
            end
          end
          
          if result[:error]
            # Check if it's warnings or actual errors
            has_real_error = false
            result[:error].strip.split("\n").each do |error_line|
              if error_line.include?("warning:")
                puts error_line.yellow  # Warnings in yellow
              else
                puts error_line.red    # Errors in red
                has_real_error = true
              end
            end
            # Only break execution on actual errors, not warnings
            break if has_real_error
          end
        end
        
        puts ""  # Spacing between blocks
      end
      
      puts "─" * 60
      puts "🎯 Demo completed!".green
    end
    
    def group_code_into_blocks(demo_code)
      blocks = []
      current_block = { lines: [], executable: false }
      
      demo_code.each do |line|
        if line.strip.empty?
          # Empty line - finish current block and start new one
          if current_block[:lines].any?
            blocks << current_block
            current_block = { lines: [], executable: false }
          end
          next
        end
        
        current_block[:lines] << line
        current_block[:executable] = true unless line.strip.start_with?("#")
      end
      
      # Add final block if it has content
      blocks << current_block if current_block[:lines].any?
      
      blocks
    end
    
    def highlight_code_line(line)
      if line.strip.start_with?("#")
        line.light_black
      elsif line.strip.match?(/^[a-zA-Z_]\w*\s*=/)
        line.magenta
      elsif line.include?("puts") || line.include?("print")
        line.white
      elsif line.include?("begin") || line.include?("rescue") || line.include?("end")
        line.white
      else
        line.white
      end
    end
    
    def add_lines_to_context(lines)
      @demo_context ||= []
      @demo_context.concat(lines)
    end
    
    def execute_single_block(lines)
      require "tempfile"
      require "open3"
      
      
      # Create script that runs all context but only shows output from current block
      script_lines = []
      
      # Check if we need to preserve frozen_string_literal pragma
      pragma_line = @demo_context.find { |line| line.include?("frozen_string_literal") }
      if pragma_line
        script_lines << pragma_line
        context_without_pragma = @demo_context.reject { |line| line.include?("frozen_string_literal") }
      else
        context_without_pragma = @demo_context
      end
      
      script_lines << "require 'stringio'"
      script_lines << "# Previous context (silent execution)"
      script_lines << "old_stdout = $stdout"
      script_lines << "$stdout = StringIO.new"  # Suppress previous output
      
      # Add all previous context except current block (excluding pragma if moved to top)
      previous_lines = context_without_pragma[0...-lines.length]
      script_lines.concat(previous_lines) if previous_lines.any?
      
      script_lines << "$stdout = old_stdout"  # Restore output for current block
      script_lines << "# Current block (with output)"
      script_lines.concat(lines)
      
      # Create temporary Ruby file
      Tempfile.create(["demo_block", ".rb"]) do |temp_file|
        final_script = script_lines.join("\n")
        temp_file.write(final_script)
        temp_file.flush
        
        
        # Execute with Ruby and capture output (with warnings enabled)
        stdout, stderr, status = Open3.capture3("ruby -w #{temp_file.path}")
        
        {
          output: stdout,
          error: stderr.strip.empty? ? nil : stderr,
          success: status.success?
        }
      end
    rescue StandardError => e
      {
        output: "",
        error: "Execution error: #{e.message}",
        success: false
      }
    end
    
    
    def display_end_screen
      # Get actual terminal dimensions
      terminal_height, terminal_width = get_terminal_size
      terminal_width -= 2
      terminal_height -= 3

      puts "╔#{"═" * (terminal_width - 2)}╗"

      # Calculate vertical centering
      content_lines = [
        "",
        "THE END",
        "",
        @talk.title,
        "",
        "Thank you!"
      ]

      padding_lines = (terminal_height - content_lines.length - 4) / 2

      # Top padding
      padding_lines.times { puts "║#{" " * (terminal_width - 2)}║" }

      # Display centered content
      content_lines.each do |line|
        line_text = case line
                    when "THE END"
                      line.bold.green
                    when @talk.title
                      line.white
                    when "Thank you!"
                      line.yellow
                    else
                      line
                    end

        display_length = line.length # Approximate, colorize adds hidden chars
        line_padding = (terminal_width - 2 - display_length) / 2
        puts "║#{" " * line_padding}#{line_text}#{" " * (terminal_width - 2 - line_padding - display_length)}║"
      end

      # Bottom padding
      padding_lines.times { puts "║#{" " * (terminal_width - 2)}║" }

      puts "╚#{"═" * (terminal_width - 2)}╝"
    end

    def start_commentary_generation(slide, slide_key)
      # Use threads instead of async for DRb compatibility
      thread = Thread.new do
        prompt = <<~PROMPT
          You're a witty AI comedian providing live commentary during a presentation slideshow.#{" "}

          Slide Title: "#{slide.title}"
          Slide Content: #{slide.content.join(", ")}

          Generate a short, funny commentary (1-2 sentences max) about this slide. Make it:
          - Clever and witty like a dad joke or pun
          - Related to the slide content
          - Family-friendly but sarcastic
          - Under 80 characters total

          Examples of the style:
          - "Frozen strings? Sounds like my ex's personality!"
          - "Memory optimization? My brain could use some of that!"
          - "Performance improvements? Unlike my coding skills!"

          Just return the joke, nothing else.
        PROMPT

        # Generate commentary using AI
        commentary = ai_ask(prompt)

        # Clean up the response
        commentary = commentary.strip.gsub(/^["']|["']$/, "") if commentary
        commentary = "#{commentary[0..116]}..." if commentary.length > 120

        @commentary_cache[slide_key] = commentary
        @commentary_ready = true
      rescue StandardError => e
        @commentary_cache[slide_key] = ["Oops, my comedy circuits are frozen!", "404: Joke not found!", "This slide broke my funny bone!"].sample
        @commentary_ready = true
      end

      # Return the thread so we can check if it's running
      thread
    end

    def generate_slide_commentary(slide)
      return nil unless @ai_available

      slide_key = "#{slide.title}_#{slide.content.join("_")}"

      # Return cached commentary if available
      return @commentary_cache[slide_key] if @commentary_cache[slide_key]

      # Return loading message if currently generating
      return "🎭 Generating comedy... stand by! 🤖" if @commentary_threads[slide_key]&.alive?

      # Start thread generation if not already started
      unless @commentary_threads[slide_key]
        @commentary_threads[slide_key] = start_commentary_generation(slide, slide_key)
      end

      # Return fallback while generating
      "🎭 Loading comedy... please wait! 🤖"
    end

    def preload_commentary_for_slides(slides, current_index)
      return unless @ai_available

      # Preload commentary for current slide and next few slides
      preload_range = [current_index - 1, current_index, current_index + 1, current_index + 2]
      preload_range.select! { |i| i >= 0 && i < slides.length }

      preload_range.each do |index|
        slide = slides[index]
        slide_key = "#{slide.title}_#{slide.content.join("_")}"

        # Skip if already cached or generating
        next if @commentary_cache[slide_key] || @commentary_threads[slide_key]&.alive?

        # Start generation in background
        generate_slide_commentary(slide)
      end
    end

    def save_commentary_cache
      return unless @talk && @current_filename

      cache_filename = @current_filename.gsub(/\.json$/, "_commentary.json")
      begin
        File.write(cache_filename, JSON.pretty_generate(@commentary_cache))
      rescue StandardError
        # Fail silently - commentary cache is not critical
      end
    end

    def load_commentary_cache
      return unless @talk && @current_filename

      cache_filename = @current_filename.gsub(/\.json$/, "_commentary.json")
      return unless File.exist?(cache_filename)

      begin
        cached_data = JSON.parse(File.read(cache_filename))
        @commentary_cache.merge!(cached_data) if cached_data.is_a?(Hash)
      rescue StandardError
        # Fail silently - commentary cache is not critical
      end
    end

    def wrap_text(text, width)
      return [""] if text.nil? || text.empty?

      words = text.split
      lines = []
      current_line = ""

      words.each do |word|
        if (current_line + word).length <= width
          current_line += (current_line.empty? ? "" : " ") + word
        else
          lines << current_line unless current_line.empty?
          current_line = word
        end
      end

      lines << current_line unless current_line.empty?
      lines.empty? ? [""] : lines
    end

    def is_code_block?(text)
      return false if text.nil? || text.strip.empty?

      # Check for common code patterns
      code_patterns = [
        /^\s*#.*frozen_string_literal/,         # Ruby pragma
        /def\s+\w+|class\s+\w+|module\s+\w+/,   # Ruby definitions
        /puts\s+|print\s+|p\s+/,                # Ruby output
        /require\s+|load\s+/,                   # Ruby requires
        /=>\s+|<<\s+|\.\w+\(/,                  # Ruby operators/method calls
        /^\s*[a-zA-Z_]\w*\s*=\s*\w+/, # Variable assignments
        /\{[^}]*\}|\[[^\]]*\]/,                 # Braces/brackets
        /function\s+\w+|const\s+\w+/,           # JavaScript
        /SELECT\s+|INSERT\s+|UPDATE\s+/i,       # SQL
        /^```/,                                 # Markdown code blocks
        /^\s{4,}/                               # Indented code (4+ spaces)
      ]

      code_patterns.any? { |pattern| text.match?(pattern) }
    end

    # Helper method to strip ANSI color codes for accurate length calculation
    def strip_ansi_codes(text)
      text.gsub(/\e\[[0-9;]*m/, "")
    end

    # Helper method to truncate text while preserving ANSI codes as much as possible
    def truncate_with_ansi(text, max_length)
      stripped = strip_ansi_codes(text)
      return text if stripped.length <= max_length

      # Simple truncation - more sophisticated preservation could be added later
      visible_chars = 0
      result = ""

      text.each_char.with_index do |char, i|
        if text[i..(i + 10)]&.match?(/\e\[[0-9;]*m/)
          # This is start of ANSI sequence, add the whole sequence
          ansi_match = text[i..].match(/\e\[[0-9;]*m/)
          if ansi_match
            result += ansi_match[0]
            ansi_match[0].length
            next
          end
        end

        break if visible_chars >= max_length

        result += char
        visible_chars += 1 unless char.match?(/\e/)
      end

      result
    end

    def format_timer(elapsed_seconds, paused = false, current_slide = nil, total_slides = nil, duration_minutes = nil)
      minutes = elapsed_seconds / 60
      seconds = elapsed_seconds % 60
      timer_text = format("%02d:%02d", minutes, seconds)

      # Calculate estimated remaining time if we have the data
      remaining_text = ""
      if current_slide && total_slides && duration_minutes && total_slides.positive?
        # Calculate progress and estimated remaining time
        progress = (current_slide + 1).to_f / total_slides
        estimated_total_seconds = duration_minutes * 60
        estimated_remaining_seconds = (estimated_total_seconds * (1 - progress)).to_i

        if estimated_remaining_seconds.positive?
          rem_minutes = estimated_remaining_seconds / 60
          rem_seconds = estimated_remaining_seconds % 60
          remaining_text = " | Est. remaining: #{format("%02d:%02d", rem_minutes, rem_seconds)}".light_black
        end
      end

      if paused
        "⏸️  #{timer_text}#{remaining_text}".yellow
      else
        "⏱️  #{timer_text}#{remaining_text}".green
      end
    end

    def get_terminal_size
      # Try to get terminal size, with fallback

      require "io/console"
      rows, cols = IO.console.winsize
      # Ensure minimum size
      rows = [rows, 20].max
      cols = [cols, 60].max
      [rows, cols]
    rescue StandardError
      # Fallback to reasonable defaults
      [24, 80]
    end

    def get_single_keypress
      require "io/console"

      # Raw mode to capture single keypress
      char = $stdin.getch

      case char
      when "\e" # Escape sequence
        next_char = $stdin.getch
        if next_char == "["
          arrow = $stdin.getch
          case arrow
          when "C" # Right arrow
            :right
          when "D" # Left arrow
            :left
          else
            :escape
          end
        else
          :escape
        end
      when " " # Space
        :space
      when "c", "C" # Commentary toggle
        :c
      when "p", "P" # Pause toggle
        :p
      when "\r", "\n" # Enter key
        :enter
      when "\u0003" # Ctrl+C
        :escape
      else
        :other
      end
    end

    def create_new_slide
      puts "\n📄 Creating new slide...".green

      slide = @talk.add_slide
      edit_slide(slide)
    end

    def create_new_image_slide
      puts "\n📷 Creating new image slide...".green

      # Check for available image viewers
      available_viewers = ImageViewer.available_viewers
      if available_viewers.empty?
        puts "\n⚠️  No image viewers found!".yellow
        puts "Install one of the following for image support:".white
        ImageViewer::VIEWERS.each_value do |config|
          puts "  • #{config[:command]} - #{config[:description]}".white
        end
        puts "\nRecommended: `brew install viu` or `apt install viu`".green
        @prompt.keypress("\nPress any key to continue...")
        return
      end

      puts "Available image viewers: #{available_viewers.keys.join(", ")}".white
      puts "Using: #{ImageViewer.preferred_viewer}".green

      # Get image path
      image_path = @prompt.ask("\n📂 Enter path to image file:", required: true) do |q|
        q.validate(/\.(jpg|jpeg|png|gif|bmp|webp)$/i, "Please enter a valid image file (jpg, png, gif, etc.)")
      end

      # Expand path and check if file exists
      full_path = File.expand_path(image_path)
      unless File.exist?(full_path)
        puts "\n❌ File not found: #{full_path}".red
        @prompt.keypress("Press any key to continue...")
        return
      end

      # Ask where to insert the slide
      position_options = []
      position_options << { name: "At the beginning (position 1)", value: 0 }

      @talk.slides.each_with_index do |existing_slide, index|
        position_options << {
          name: "After slide #{index + 1}: \"#{existing_slide.title}\"",
          value: index + 1
        }
      end

      position_options << { name: "At the end (position #{@talk.slides.length + 1})", value: @talk.slides.length }

      position = @prompt.select("\n📍 Where would you like to insert this image slide?", position_options)

      # Create image slide at specified position
      slide = @talk.insert_slide_at(position)
      slide.slide_type = :image
      slide.image_path = full_path

      # Get title
      default_title = File.basename(full_path, ".*").gsub(/[_-]/, " ").split.map(&:capitalize).join(" ")
      slide.title = @prompt.ask("📝 Slide title:", default: default_title, required: true)

      # Ask if they want to add content too (mixed slide)
      if @prompt.yes?("\n➕ Add text content to this image slide? (creates a mixed slide)")
        slide.slide_type = :mixed
        edit_slide_content(slide)
      end

      # Add notes
      notes = @prompt.multiline("\n📋 Speaker notes (optional, press Enter twice when done):")
      slide.notes = notes.join("\n") if notes&.any?

      puts "\n✅ Image slide created successfully!".green
      ImageViewer.display_image_info(full_path)

      auto_save
    end

    def create_ai_slide
      return unless @ai_available

      puts "\n🤖 Generating AI suggestions...".yellow

      begin
        previous_slides = @talk.slides.map(&:to_hash)
        ai_prompt = AIPersona.slide_creation_prompt(
          @talk.title,
          @talk.description,
          @talk.slides.length + 1,
          previous_slides,
        )

        response = ai_ask_with_spinner(ai_prompt, message: "Generating slide suggestions...")

        puts "\n🎯 AI Suggestions:".white
        puts response.white

        if @prompt.yes?("\nWould you like to create a slide based on these suggestions?")
          slide = @talk.add_slide

          # Try to parse AI response for title and content
          lines = response.split("\n").reject(&:empty?)
          title_line = lines.find { |line| line.downcase.include?("title") }

          if title_line
            suggested_title = title_line.split(":").last&.strip
            slide.title = suggested_title if suggested_title
          end

          edit_slide(slide, ai_suggestions: response)
        end
      rescue StandardError => e
        puts "❌ AI assistance failed: #{e.message}".red
        create_new_slide
      end
    end

    def edit_slide_menu
      return puts "No slides to edit yet.".yellow if @talk.slides.empty?

      slide_choices = @talk.slides.map.with_index do |slide, index|
        { name: slide.display_summary, value: index }
      end

      slide_index = @prompt.select("Which slide would you like to edit?", slide_choices)
      edit_slide(@talk.slides[slide_index])
    end

    def edit_slide(slide, ai_suggestions: nil)
      loop do
        puts "\n#{"─" * 50}"
        slide_index = @talk.slides.index(slide) + 1
        puts "Editing Slide #{slide_index}:".bold
        puts slide

        if ai_suggestions
          puts "\n🤖 AI Suggestions:".white
          puts ai_suggestions.white
          ai_suggestions = nil # Only show once
        end

        choice = @prompt.select("\nWhat would you like to do?", [
                                  { name: "Edit title", value: :title },
                                  { name: "Add content point", value: :add_content },
                                  { name: "Edit content point", value: :edit_content },
                                  { name: "Remove content point", value: :remove_content },
                                  { name: "Add speaker notes", value: :notes },
                                  { name: "Get AI improvement suggestions", value: :ai_improve },
                                  { name: "Done editing", value: :done },
                                ])

        case choice
        when :title
          new_title = @prompt.ask("Enter slide title:", default: slide.title)
          slide.title = new_title
        when :add_content
          content = @prompt.ask("Enter content point:")
          slide.add_content(content) unless content.strip.empty?
        when :edit_content
          edit_slide_content(slide)
        when :remove_content
          remove_slide_content(slide)
        when :notes
          notes = @prompt.multiline("Enter speaker notes:", default: slide.notes).join("\n")
          slide.notes = notes
        when :ai_improve
          get_ai_improvement_suggestions(slide)
        when :done
          auto_save # Auto-save after editing slide
          break
        end
      end
    end

    def edit_slide_content(slide)
      return puts "No content to edit.".yellow if slide.content.empty?

      content_choices = slide.content.map.with_index do |content, index|
        { name: "#{index + 1}. #{content}", value: index }
      end

      index = @prompt.select("Which content point would you like to edit?", content_choices)
      new_content = @prompt.ask("Edit content:", default: slide.content[index])
      slide.update_content(index, new_content)
    end

    def remove_slide_content(slide)
      return puts "No content to remove.".yellow if slide.content.empty?

      content_choices = slide.content.map.with_index do |content, index|
        { name: "#{index + 1}. #{content}", value: index }
      end

      index = @prompt.select("Which content point would you like to remove?", content_choices)
      slide.remove_content(index)
    end

    def get_ai_improvement_suggestions(slide)
      return unless @ai_available

      puts "\n🤖 Getting AI improvement suggestions...".yellow

      begin
        feedback = @prompt.ask("Any specific areas you'd like feedback on? (optional):")
        ai_prompt = AIPersona.slide_improvement_prompt(slide.title, slide.content.join("\n"), feedback)

        response = ai_ask_with_spinner(ai_prompt, message: "Getting improvement suggestions...")

        puts "\n🎯 AI Improvement Suggestions:".white
        puts response.white

        @prompt.keypress("\nPress any key to continue editing...")
      rescue StandardError => e
        puts "❌ AI assistance failed: #{e.message}".red
      end
    end

    def reorder_slides
      return puts "Need at least 2 slides to reorder.".yellow if @talk.slides.length < 2

      puts "\nCurrent slide order:".bold
      @talk.slides.each { |slide| puts slide.display_summary }

      from_index = @prompt.ask("Which slide number to move?", convert: :int) - 1
      to_index = @prompt.ask("Move to which position?", convert: :int) - 1

      if @talk.move_slide(from_index, to_index)
        puts "✅ Slides reordered successfully!".green
        auto_save # Auto-save after reordering slides
      else
        puts "❌ Invalid slide positions.".red
      end
    end

    def delete_slide
      return puts "No slides to delete.".yellow if @talk.slides.empty?

      slide_choices = @talk.slides.map.with_index do |slide, index|
        { name: slide.display_summary, value: index }
      end

      slide_index = @prompt.select("Which slide would you like to delete?", slide_choices)
      slide = @talk.slides[slide_index]

      return unless @prompt.yes?("Are you sure you want to delete '#{slide.title}'?")

      @talk.remove_slide(slide_index)
      puts "✅ Slide deleted successfully!".green
      auto_save # Auto-save after deleting slide
    end

    def ai_assistance_menu
      return puts "AI assistance is not available.".red unless @ai_available

      loop do
        fact_check_option = if @serper_client.available?
                              { name: "Fact-check slides with Google search", value: :fact_check }
                            else
                              { name: "Fact-check slides (requires Serper API key)", value: :fact_check,
                                disabled: true }
                            end

        choice = @prompt.select("How can AI help you?", [
                                  { name: "Create next slide", value: :next_slide },
                                  { name: "AI Fix Mode - Add/Insert multiple slides", value: :ai_fix_mode },
                                  { name: "Improve existing slide", value: :improve_slide },
                                  { name: "Review and Fix Structure", value: :review_and_fix_structure },
                                  { name: "Integrate web content into slides", value: :web_content },
                                  fact_check_option,
                                  { name: "Get presentation tips", value: :tips },
                                  { name: "Back to main menu", value: :back },
                                ])

        case choice
        when :next_slide
          create_ai_slide
        when :ai_fix_mode
          ai_fix_mode
        when :improve_slide
          ai_improve_existing_slide
        when :review_and_fix_structure
          ai_review_and_fix_structure
        when :web_content
          integrate_web_content
        when :fact_check
          fact_check_slides
        when :tips
          ai_presentation_tips
        when :back
          break
        end
      end
    end

    def ai_improve_existing_slide
      return puts "No slides to improve.".yellow if @talk.slides.empty?

      slide_choices = @talk.slides.map.with_index do |slide, index|
        { name: slide.display_summary, value: index }
      end

      slide_index = @prompt.select("Which slide needs improvement?", slide_choices)
      get_ai_improvement_suggestions(@talk.slides[slide_index])
    end

    def ai_review_and_fix_structure
      puts "\n🔍 Review and Fix Structure".cyan.bold
      puts "AI will analyze your presentation structure and offer to fix issues automatically.".white

      return puts "No slides to review yet.".yellow if @talk.slides.empty?

      # Get user input on what to focus on
      puts "\n📋 What would you like the AI to focus on?".yellow
      puts "Select at least one area (use SPACE to select, ENTER to confirm):".white

      focus_areas = []
      while focus_areas.empty?
        focus_areas = @prompt.multi_select("Select areas to review and fix:", [
                                             { name: "Flow and transitions between slides", value: :flow },
                                             { name: "Missing introduction/conclusion structure",
                                               value: :intro_conclusion },
                                             { name: "Slide count vs duration (pacing)", value: :pacing },
                                             { name: "Missing examples or case studies", value: :examples },
                                             { name: "Lack of interactive elements", value: :interactive },
                                             { name: "Content depth and balance", value: :depth },
                                             { name: "Audience engagement opportunities", value: :engagement },
                                             { name: "Technical accuracy and completeness", value: :technical },
                                             { name: "Repetition or redundant content", value: :redundancy },
                                             { name: "Overall presentation coherence", value: :coherence }
                                           ])

        next unless focus_areas.empty?

        puts "\n⚠️  Please select at least one area to analyze.".yellow
        unless @prompt.yes?("Try again?")
          puts "Analysis cancelled.".white
          return
        end
      end

      # Get specific issues user has noticed
      specific_issues = @prompt.multiline("Any specific issues you've noticed? (Press Enter twice when done, or leave blank)").join("\n")

      # Get target outcome
      target_outcome = @prompt.ask("What's your main goal for this presentation?",
                                   default: "Engage audience and clearly communicate key concepts")

      puts "\n🤖 Analyzing presentation structure...".yellow
      puts "   Focus areas: #{focus_areas.map(&:to_s).join(", ")}"
      puts "   Looking for fixes and improvements...".white

      begin
        # Step 1: Get text-based analysis first
        puts "\n📊 Step 1: Analyzing presentation structure...".yellow
        analysis_prompt = build_text_analysis_prompt(focus_areas, specific_issues, target_outcome)

        text_analysis = ai_ask_with_spinner(analysis_prompt, message: "Analyzing presentation structure...")

        if text_analysis.nil? || text_analysis.strip.empty?
          puts "❌ AI did not provide analysis. Please try again.".red
          return
        end

        # Display the text analysis
        puts "\n🔍 Structure Analysis:".white.bold
        puts text_analysis.white

        # Ask if user wants to proceed with auto-fixes
        return unless @prompt.yes?("\n🔧 Would you like me to generate and apply fixes automatically?")

        # Step 2: Get JSON fixes based on the analysis
        puts "\n📊 Step 2: Generating specific fixes...".yellow
        fixes_prompt = build_json_fixes_prompt(text_analysis, focus_areas, target_outcome)

        json_response = ai_ask_with_spinner(fixes_prompt, message: "Generating actionable fixes...")

        if json_response.nil? || json_response.strip.empty?
          puts "❌ AI did not provide fixes. Please try again.".red
          return
        end

        puts "   Parsing fix response...".white
        issues_and_fixes = parse_structure_analysis(json_response)

        if issues_and_fixes && issues_and_fixes["fixes"]&.any?
          puts "\n🔄 Auto-Fix Mode Activated".cyan.bold
          puts "I'll automatically apply fixes and re-analyze for continuous improvement.".white

          # Iterative improvement loop
          iteration = 1
          max_iterations = 3
          total_fixes_applied = 0

          loop do
            puts "\n📍 Iteration #{iteration}/#{max_iterations}".yellow

            fixes_to_apply = issues_and_fixes["fixes"].select { |fix| can_auto_apply?(fix) }

            if fixes_to_apply.empty?
              puts "No more auto-applicable fixes found.".white
              break
            end

            puts "Found #{fixes_to_apply.length} fixes to apply...".white
            fixes_applied = apply_structure_fixes_auto(fixes_to_apply)
            total_fixes_applied += fixes_applied

            break if iteration >= max_iterations

            unless fixes_applied.positive? && @prompt.yes?("\n🔄 #{fixes_applied} fixes applied. Continue improving? (Iteration #{iteration + 1}/#{max_iterations})")
              break
            end

            iteration += 1
            puts "\n🔍 Re-analyzing structure after fixes...".yellow

            # Re-run the JSON fixes prompt with updated presentation
            json_response = ai_ask_with_spinner(fixes_prompt, message: "Re-analyzing presentation structure...")
            new_issues_and_fixes = parse_structure_analysis(json_response)

            if new_issues_and_fixes && new_issues_and_fixes["fixes"]&.any?
              puts "\n📊 New Analysis Results:".white
              puts "Found #{new_issues_and_fixes["fixes"].length} additional improvements".white
              issues_and_fixes = new_issues_and_fixes
            else
              puts "\n✅ No more improvements needed!".green
              break
            end
          end

          puts "\n🎉 Auto-Fix Complete!".green.bold
          puts "Total fixes applied: #{total_fixes_applied}".white
          puts "Iterations completed: #{iteration}".white

          # Show final structure overview
          if total_fixes_applied.positive? && @prompt.yes?("\nWould you like to see the improved structure?")
            show_talk_overview
          end
        else
          puts "\n⚠️  No applicable fixes found in the response.".yellow
          puts "The analysis was helpful, but no automatic fixes could be generated.".white
        end
      rescue StandardError => e
        puts "❌ Analysis failed: #{e.message}".red
        puts "This might be due to AI connectivity or parsing issues.".yellow
        @prompt.keypress("\nPress any key to continue...")
      end
    end

    def build_structure_review_prompt(focus_areas, specific_issues, target_outcome)
      # Build detailed analysis sections based on focus areas
      analysis_sections = []

      if focus_areas.include?(:flow)
        analysis_sections << "- Flow and transitions: Are slides logically ordered? Are transitions smooth?"
      end

      if focus_areas.include?(:intro_conclusion)
        analysis_sections << "- Introduction/Conclusion: Strong opening and closing? Clear agenda and takeaways?"
      end

      if focus_areas.include?(:pacing)
        analysis_sections << "- Pacing: Is #{@talk.slides.length} slides appropriate for #{@talk.duration_minutes} minutes?"
      end

      if focus_areas.include?(:examples)
        analysis_sections << "- Examples: Are there enough practical examples and case studies?"
      end

      if focus_areas.include?(:interactive)
        analysis_sections << "- Interactivity: Are there Q&A breaks, exercises, or audience engagement points?"
      end

      if focus_areas.include?(:depth)
        analysis_sections << "- Content depth: Is coverage balanced? Too shallow or too deep anywhere?"
      end

      if focus_areas.include?(:engagement)
        analysis_sections << "- Engagement: Will the audience stay interested throughout?"
      end

      if focus_areas.include?(:technical)
        analysis_sections << "- Technical accuracy: Are technical concepts properly explained and sequenced?"
      end

      if focus_areas.include?(:redundancy)
        analysis_sections << "- Redundancy: Is there repetitive or overlapping content?"
      end

      if focus_areas.include?(:coherence)
        analysis_sections << "- Coherence: Does the presentation tell a clear, unified story?"
      end

      <<~PROMPT
        Analyze this presentation structure and provide actionable fixes:

        **Presentation Details:**
        Title: #{@talk.title}
        Description: #{@talk.description}
        Duration: #{@talk.duration_minutes} minutes
        Audience: #{@talk.target_audience}
        Current Slides: #{@talk.slides.length}
        Goal: #{target_outcome}

        **Current Structure:**
        #{@talk.slides.map.with_index(1) { |slide, i| "#{i}. #{slide.title}\n   Content: #{slide.content.join(", ")}" }.join("\n\n")}

        #{"\n**Specific Issues to Address:**\n#{specific_issues}" unless specific_issues.empty?}

        **Focus Areas for Analysis:**
        #{analysis_sections.join("\n")}

        **Required Analysis Format:**
        Provide your response in this JSON format:
        {
          "issues_found": [
            {
              "category": "flow|pacing|content|structure|engagement",
              "severity": "high|medium|low",
              "description": "detailed description of the issue",
              "affected_slides": [slide_numbers],
              "impact": "how this affects the presentation"
            }
          ],
          "fixes": [
            {
              "type": "add_slide",
              "description": "what this fix does",
              "action": "detailed implementation",
              "position": "where to apply (slide numbers or 'after_slide_X')",
              "new_content": {
                "title": "slide title if creating new slide",
                "content": ["bullet points if creating new slide"],
                "notes": "speaker notes if creating new slide"
              }
            }
          ],
          "overall_assessment": "summary of presentation quality and recommended priority fixes"
        }

        **IMPORTANT FIX TYPE RULES:**
        - Use ONLY these exact fix types: "add_slide", "modify_slide", "reorder_slides", "split_slide", "merge_slides"
        - Use ONE type per fix, never combine types like "add_slide|modify_slide"
        - For complex changes, create multiple separate fixes
        - STRONGLY PRIORITIZE "add_slide" and "modify_slide" as these can be applied automatically
        - When possible, break down complex fixes into multiple "add_slide" or "modify_slide" operations

        Focus on providing 3-7 high-impact fixes that address the most critical issues.
        At least 70% of your fixes should be "add_slide" or "modify_slide" type.
        Provide specific, detailed content in the new_content field for automatic application.
      PROMPT
    end

    def build_text_analysis_prompt(focus_areas, specific_issues, target_outcome)
      # Build detailed analysis sections based on focus areas
      analysis_sections = []

      if focus_areas.include?(:flow)
        analysis_sections << "- Flow and transitions: Are slides logically ordered? Are transitions smooth?"
      end

      if focus_areas.include?(:intro_conclusion)
        analysis_sections << "- Introduction/Conclusion: Strong opening and closing? Clear agenda and takeaways?"
      end

      if focus_areas.include?(:pacing)
        analysis_sections << "- Pacing: Is #{@talk.slides.length} slides appropriate for #{@talk.duration_minutes} minutes?"
      end

      if focus_areas.include?(:examples)
        analysis_sections << "- Examples: Are there enough practical examples and case studies?"
      end

      if focus_areas.include?(:interactive)
        analysis_sections << "- Interactivity: Are there Q&A breaks, exercises, or audience engagement points?"
      end

      if focus_areas.include?(:depth)
        analysis_sections << "- Content depth: Is coverage balanced? Too shallow or too deep anywhere?"
      end

      if focus_areas.include?(:engagement)
        analysis_sections << "- Engagement: Will the audience stay interested throughout?"
      end

      if focus_areas.include?(:technical)
        analysis_sections << "- Technical accuracy: Are technical concepts properly explained and sequenced?"
      end

      if focus_areas.include?(:redundancy)
        analysis_sections << "- Redundancy: Is there repetitive or overlapping content?"
      end

      if focus_areas.include?(:coherence)
        analysis_sections << "- Coherence: Does the presentation tell a clear, unified story?"
      end

      <<~PROMPT
        Analyze this presentation structure and provide a detailed text analysis:

        **Presentation Details:**
        Title: #{@talk.title}
        Description: #{@talk.description}
        Duration: #{@talk.duration_minutes} minutes
        Audience: #{@talk.target_audience}
        Current Slides: #{@talk.slides.length}
        Goal: #{target_outcome}

        **Current Structure:**
        #{@talk.slides.map.with_index(1) { |slide, i| "#{i}. #{slide.title}\n   Content: #{slide.content.join(", ")}" }.join("\n\n")}

        #{"\n**Specific Issues to Address:**\n#{specific_issues}" unless specific_issues.empty?}

        **Focus Areas for Analysis:**
        #{analysis_sections.join("\n")}

        Provide a comprehensive analysis covering:
        1. Major structural issues you identify
        2. Flow and pacing problems
        3. Content gaps or redundancies
        4. Audience engagement opportunities
        5. Areas that need improvement

        Write this as a clear, readable analysis that explains the issues and why they matter.
        Do NOT include JSON or fixes in this response - just the analysis.
      PROMPT
    end

    def build_json_fixes_prompt(text_analysis, _focus_areas, target_outcome)
      <<~PROMPT
        Based on this analysis of the presentation:

        #{text_analysis}

        **Current Presentation Structure:**
        Title: #{@talk.title}
        Description: #{@talk.description}
        Duration: #{@talk.duration_minutes} minutes
        Audience: #{@talk.target_audience}
        Goal: #{target_outcome}

        **Current Slides:**
        #{@talk.slides.map.with_index(1) { |slide, i| "#{i}. #{slide.title}\n   Content: #{slide.content.join(", ")}" }.join("\n\n")}

        Generate specific, actionable fixes in JSON format.

        **CRITICAL JSON FORMAT REQUIREMENTS:**
        Respond with ONLY valid JSON in exactly this format (no extra text):
        {
          "fixes": [
            {
              "type": "add_slide",
              "description": "what this fix does",
              "action": "detailed implementation",
              "position": "after_slide_X" or "end",
              "new_content": {
                "title": "slide title",
                "content": ["bullet point 1", "bullet point 2", "bullet point 3"],
                "notes": "speaker notes"
              }
            },
            {
              "type": "modify_slide",
              "description": "what this fix does",
              "action": "detailed implementation",#{" "}
              "position": "slide_X",
              "new_content": {
                "title": "updated title",
                "content": ["updated point 1", "updated point 2"],
                "notes": "updated notes"
              }
            }
          ]
        }

        **FIX TYPE RULES:**
        - Use ONLY "add_slide" or "modify_slide" types
        - For "add_slide": specify position as "after_slide_X" or "end"
        - For "modify_slide": specify position as "slide_X" (where X is slide number)
        - Always provide complete new_content with title, content array, and notes
        - Focus on 3-5 high-impact fixes that address the analysis issues

        IMPORTANT: Return ONLY the JSON object, no explanatory text before or after.
      PROMPT
    end

    def parse_structure_analysis(response)
      parsed = parse_ai_json_response(response)
      return parsed if parsed && (parsed["issues_found"] || parsed["fixes"])

      # If JSON parsing failed, return nil to fall back to plain text display
      nil
    end

    def display_structure_analysis(analysis)
      puts "\n📊 Structure Analysis Results:".white.bold

      if analysis["issues_found"]&.any?
        puts "\n🔍 Issues Found:".red.bold
        analysis["issues_found"].each_with_index do |issue, i|
          severity_color = case issue["severity"]
                           when "high" then :red
                           when "medium" then :yellow
                           when "low" then :light_blue
                           else :white
                           end

          puts "\n#{i + 1}. #{issue["description"]}".send(severity_color)
          puts "   Category: #{issue["category"].capitalize}".white
          puts "   Severity: #{issue["severity"].upcase}".send(severity_color)
          puts "   Affects slides: #{issue["affected_slides"]&.join(", ") || "Multiple"}".white
          puts "   Impact: #{issue["impact"]}".white if issue["impact"]
        end
      end

      if analysis["fixes"]&.any?
        puts "\n🛠️  Suggested Fixes:".green.bold
        analysis["fixes"].each_with_index do |fix, i|
          puts "\n#{i + 1}. #{fix["description"]}".green
          puts "   Type: #{fix["type"].gsub("_", " ").capitalize}".white
          puts "   Action: #{fix["action"]}".white
          puts "   Position: #{fix["position"]}".white if fix["position"]
        end
      end

      return unless analysis["overall_assessment"]

      puts "\n📋 Overall Assessment:".cyan.bold
      puts analysis["overall_assessment"].white
    end

    def can_auto_apply?(fix)
      fix_type = parse_fix_type(fix["type"])
      %w[add_slide modify_slide].include?(fix_type)
    end

    def apply_structure_fixes_auto(fixes)
      fixes_applied = 0

      fixes.each_with_index do |fix, i|
        puts "\n#{i + 1}. #{fix["description"]}".white

        begin
          # Parse fix type (handle compound types)
          fix_type = parse_fix_type(fix["type"])

          case fix_type
          when "add_slide"
            apply_add_slide_fix(fix)
            fixes_applied += 1
            puts "   ✅ Applied successfully".green
          when "modify_slide"
            apply_modify_slide_fix(fix)
            fixes_applied += 1
            puts "   ✅ Applied successfully".green
          else
            puts "   ⏭️  Skipping (requires manual action)".yellow
          end
        rescue StandardError => e
          puts "   ❌ Failed to apply: #{e.message}".red
        end
      end

      if fixes_applied.positive?
        # Renumber all slides
        # Slide numbers are now calculated dynamically
        auto_save
      end

      fixes_applied
    end

    def apply_structure_fixes(fixes)
      puts "\n🔧 Applying structure fixes...".yellow
      fixes_applied = 0

      fixes.each_with_index do |fix, i|
        puts "\n#{i + 1}. #{fix["description"]}".white

        begin
          # Parse fix type (handle compound types)
          fix_type = parse_fix_type(fix["type"])

          case fix_type
          when "add_slide"
            apply_add_slide_fix(fix)
          when "modify_slide"
            apply_modify_slide_fix(fix)
          when "reorder_slides"
            apply_reorder_fix(fix)
          when "split_slide"
            apply_split_slide_fix(fix)
          when "merge_slides"
            apply_merge_slides_fix(fix)
          else
            # Try to provide helpful guidance for unsupported fixes
            provide_manual_fix_guidance(fix)
            next
          end

          fixes_applied += 1
          puts "   ✅ Applied successfully".green
        rescue StandardError => e
          puts "   ❌ Failed to apply: #{e.message}".red
        end
      end

      if fixes_applied.positive?
        # Renumber all slides
        # Slide numbers are now calculated dynamically
        auto_save

        puts "\n🎉 Applied #{fixes_applied}/#{fixes.length} fixes successfully!".green.bold
        puts "Your presentation structure has been improved.".white

        show_talk_overview if @prompt.yes?("\nWould you like to review the updated structure?")
      else
        puts "\n⚠️  No fixes could be applied automatically.".yellow
        puts "Please review the suggestions and make manual changes.".white
      end
    end

    def apply_add_slide_fix(fix)
      # Generate content if not provided
      if fix["new_content"]
        slide_title = fix["new_content"]["title"] || generate_slide_title_from_fix(fix)
        slide_content = fix["new_content"]["content"] || generate_slide_content_from_fix(fix)
        slide_notes = fix["new_content"]["notes"] || generate_slide_notes_from_fix(fix)
      else
        slide_title = generate_slide_title_from_fix(fix)
        slide_content = generate_slide_content_from_fix(fix)
        slide_notes = generate_slide_notes_from_fix(fix)
      end

      slide = Slide.new(
        title: slide_title,
        content: slide_content,
        notes: slide_notes
      )

      # Determine insertion position
      if fix["position"] == "end"
        @talk.slides << slide
      elsif fix["position"]&.start_with?("after_slide_")
        position = fix["position"].sub("after_slide_", "").to_i
        position = [position, @talk.slides.length].min
        @talk.slides.insert(position, slide)
      else
        @talk.slides << slide
      end

      puts "   Added slide: #{slide.title}".green
    end

    def generate_slide_title_from_fix(fix)
      description = fix["description"].downcase

      if description.include?("example") || description.include?("case study")
        "Real-World Example"
      elsif description.include?("interactive") || description.include?("engagement")
        "Interactive Element"
      elsif description.include?("summary") || description.include?("recap")
        "Summary"
      elsif description.include?("introduction") || description.include?("intro")
        "Introduction"
      elsif description.include?("conclusion") || description.include?("wrap")
        "Conclusion"
      else
        "New Content Slide"
      end
    end

    def generate_slide_content_from_fix(fix)
      description = fix["description"].downcase
      action = fix["action"] || ""

      if description.include?("example") || description.include?("case study")
        [
          "Real-world scenario or use case",
          "Step-by-step walkthrough",
          "Key insights and takeaways",
          "Discussion: How does this apply to your work?"
        ]
      elsif description.include?("interactive") || description.include?("engagement")
        [
          "Quick poll: [Ask audience a relevant question]",
          "Small group discussion (2-3 minutes)",
          "Share insights with the larger group",
          "Q&A opportunity"
        ]
      elsif description.include?("summary") || description.include?("recap")
        [
          "Key points covered so far",
          "Main takeaways",
          "How this connects to what's next"
        ]
      else
        # Generate generic content based on the action
        content = ["Main concept or idea"]
        content << "Supporting details" if action.length > 50
        content << "Examples or applications"
        content << "Key takeaway"
        content
      end
    end

    def generate_slide_notes_from_fix(fix)
      "Speaker notes: #{fix["action"] || fix["description"]}"
    end

    def apply_modify_slide_fix(fix)
      # Extract slide number from position or action
      slide_num = extract_slide_number(fix["position"] || fix["action"])
      return unless slide_num&.positive? && slide_num <= @talk.slides.length

      slide = @talk.slides[slide_num - 1]

      if fix["new_content"]
        slide.title = fix["new_content"]["title"] if fix["new_content"]["title"]
        slide.content = fix["new_content"]["content"] if fix["new_content"]["content"]
        slide.notes = fix["new_content"]["notes"] if fix["new_content"]["notes"]
      end

      puts "   Modified slide #{slide_num}: #{slide.title}".green
    end

    def apply_reorder_fix(fix)
      # This would require more complex parsing of the fix action
      # For now, just notify that manual reordering is needed
      puts "   ⚠️  Slide reordering requires manual action".yellow
      puts "   Suggestion: #{fix["action"]}".white
    end

    def apply_split_slide_fix(fix)
      # Complex operation - notify user to do manually
      puts "   ⚠️  Slide splitting requires manual action".yellow
      puts "   Suggestion: #{fix["action"]}".white
    end

    def apply_merge_slides_fix(fix)
      # Complex operation - notify user to do manually
      puts "   ⚠️  Slide merging requires manual action".yellow
      puts "   Suggestion: #{fix["action"]}".white
    end

    def extract_slide_number(text)
      return nil unless text

      match = text.match(/slide[_\s]?(\d+)/i)
      match ? match[1].to_i : nil
    end

    def parse_fix_type(type_string)
      return nil unless type_string

      # Handle compound types like "modify_slide|reorder_slides"
      types = type_string.split("|").map(&:strip)

      # Prioritize types we can actually handle
      preferred_order = %w[add_slide modify_slide reorder_slides split_slide merge_slides]

      # Return the first type we can handle
      preferred_order.each do |preferred_type|
        return preferred_type if types.include?(preferred_type)
      end

      # If no preferred type found, return the first one
      types.first
    end

    def provide_manual_fix_guidance(fix)
      puts "   ⚠️  Cannot apply automatically: #{fix["type"]}".yellow

      case fix["type"]
      when /reorder|rearrange/i
        puts "   💡 Manual steps: Use 'Reorder slides' from the main menu".white
        puts "      Suggestion: #{fix["action"]}".white
      when /split|divide/i
        puts "   💡 Manual steps: Edit the slide and break content into multiple slides".white
        puts "      Suggestion: #{fix["action"]}".white
      when /merge|combine/i
        puts "   💡 Manual steps: Copy content from multiple slides into one".white
        puts "      Suggestion: #{fix["action"]}".white
      when /interactive|engagement/i
        puts "   💡 Manual steps: Edit slides to add interactive elements".white
        puts "      Ideas: Add Q&A prompts, polls, or exercises".white
      when /example|case.?study/i
        puts "   💡 Manual steps: Add new slides with real-world examples".white
        puts "      Use 'Create new slide' and add practical examples".white
      else
        puts "   💡 Manual steps required:".white
        puts "      #{fix["action"]}".white

        # Try to suggest the best approach based on the description
        description = fix["description"].downcase
        if description.include?("add") || description.include?("create")
          puts "      → Consider using 'Create new slide' from the main menu".white
        elsif description.include?("edit") || description.include?("modify") || description.include?("update")
          puts "      → Use 'Edit existing slide' from the main menu".white
        elsif description.include?("remove") || description.include?("delete")
          puts "      → Use 'Delete slide' from the main menu".white
        end
      end
    end

    def ai_presentation_tips
      puts "\n🤖 Getting presentation tips...".yellow

      begin
        tips_prompt = "Provide 5-7 practical tips for delivering an engaging presentation on '#{@talk.title}' to #{@talk.target_audience}. Focus on delivery, audience engagement, and handling Q&A."

        response = ai_ask_with_spinner(tips_prompt, message: "Generating presentation tips...")

        puts "\n🎯 Presentation Tips:".white
        puts response.white

        @prompt.keypress("\nPress any key to continue...")
      rescue StandardError => e
        puts "❌ AI assistance failed: #{e.message}".red
      end
    end

    def integrate_web_content
      puts "\n🌐 Integrate Web Content".cyan.bold
      puts "Fetch content from a website and incorporate it into your slides.".white

      # Get URL from user
      url = @prompt.ask("\nEnter the URL of the website:")
      return if url.strip.empty?

      puts "\n🔍 Fetching content from #{url}...".yellow

      # Fetch web content
      fetcher = WebContentFetcher.new
      result = fetcher.fetch_content(url)

      unless result[:success]
        puts "❌ Failed to fetch content: #{result[:error]}".red
        return
      end

      puts "✅ Content fetched successfully!".green
      puts "📄 Content length: #{result[:content].length} characters".white

      # Show preview of content
      preview = result[:content][0..500]
      preview += "..." if result[:content].length > 500

      puts "\n📋 Content Preview:".white
      puts preview.white

      unless @prompt.yes?("\nWould you like to proceed with integrating this content?")
        puts "Integration cancelled.".yellow
        return
      end

      # Ask how to integrate the content
      integration_choice = @prompt.select("\nHow would you like to integrate this content?", [
                                            { name: "Add new slides with this content", value: :new_slides },
                                            { name: "Update existing slides with this content", value: :update_slides },
                                            { name: "Create summary slide from this content", value: :summary_slide }
                                          ])

      case integration_choice
      when :new_slides
        integrate_as_new_slides(result[:content], result[:url])
      when :update_slides
        integrate_into_existing_slides(result[:content], result[:url])
      when :summary_slide
        create_summary_slide(result[:content], result[:url])
      end
    end

    def integrate_as_new_slides(web_content, source_url)
      puts "\n📄 Creating new slides from web content...".yellow

      # Ask for customization
      focus_area = @prompt.multiline("What specific aspects should we focus on? (Press Enter twice when done, or leave blank for general content)").join("\n")
      slide_count = @prompt.ask("How many slides should we create from this content?", convert: :int, default: 3)

      begin
        integration_prompt = <<~PROMPT
          Create #{slide_count} presentation slides from this web content:

          Source URL: #{source_url}
          Content: #{web_content}

          Presentation context:
          Title: #{@talk.title}
          Description: #{@talk.description}
          Target Audience: #{@talk.target_audience}

          #{"Focus on: #{focus_area}" unless focus_area.empty?}

          Instructions:
          1. Extract the most relevant and valuable information
          2. Create engaging slide titles
          3. Organize content into clear, digestible points
          4. Include the source URL in speaker notes
          5. Make it flow well with the existing presentation

          IMPORTANT: Respond ONLY with valid JSON in this format:
          {
            "slides": [
              {
                "title": "slide title",
                "content": ["point 1", "point 2", "point 3"],
                "speaker_notes": "detailed notes including source reference"
              }
            ]
          }
        PROMPT

        response = ai_ask_with_spinner(integration_prompt, message: "Creating slides from web content...")
        slides_data = parse_ai_json_response(response)

        if slides_data && slides_data["slides"]
          position = @prompt.ask("Insert after which slide? (0 for beginning, #{@talk.slides.length} for end):",
                                 convert: :int, default: @talk.slides.length)
          position = [[position, 0].max, @talk.slides.length].min

          slides_data["slides"].reverse.each do |slide_data|
            slide = Slide.new(
              title: slide_data["title"],
              content: slide_data["content"] || [],
              notes: "#{slide_data["speaker_notes"] || ""}\n\nSource: #{source_url}"
            )
            @talk.slides.insert(position, slide)
            puts "✅ Added: #{slide.title}".green
          end

          # Renumber all slides
          # Slide numbers are now calculated dynamically
          auto_save

          puts "\n🎉 Created #{slides_data["slides"].length} slides from web content!".green.bold
        else
          puts "❌ Failed to generate slides from web content".red
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}".red
      end
    end

    def integrate_into_existing_slides(web_content, source_url)
      return puts "No slides to update yet.".yellow if @talk.slides.empty?

      puts "\n📝 Analyzing slides for web content integration...".yellow

      # Step 1: AI analyzes which slides would benefit from web content
      analysis_prompt = build_slide_matching_prompt(web_content, source_url)

      puts "🔍 Finding slides that match the web content...".white
      matching_response = ai_ask_with_spinner(analysis_prompt, message: "Analyzing slide relevance...")

      if matching_response.nil? || matching_response.strip.empty?
        puts "❌ Could not analyze slide relevance. Falling back to manual selection.".red
        return manual_slide_selection(web_content, source_url)
      end

      # Parse the matching analysis
      slide_matches = parse_slide_matching_response(matching_response)

      if slide_matches.empty?
        puts "\n📋 Analysis Results:".white
        puts matching_response.white
        puts "\n⚠️  No highly relevant slides found for this content.".yellow

        choice = @prompt.select("What would you like to do?", [
                                  { name: "Try manual slide selection", value: :manual },
                                  { name: "Create new slides instead", value: :new_slides },
                                  { name: "Cancel integration", value: :cancel }
                                ])

        case choice
        when :manual
          return manual_slide_selection(web_content, source_url)
        when :new_slides
          return integrate_as_new_slides(web_content, source_url)
        when :cancel
          return
        end
      end

      # Display the AI recommendations
      puts "\n🎯 AI Found Relevant Slides:".white.bold
      slide_matches.each_with_index do |match, i|
        slide = @talk.slides[match[:slide_index]]
        puts "\n#{i + 1}. #{slide.display_summary}".green
        puts "   Relevance: #{match[:relevance]}".white
        puts "   Why: #{match[:reason]}".white
        puts "   Suggested enhancement: #{match[:enhancement]}".white
      end

      unless @prompt.yes?("\n🚀 Apply these enhancements automatically?")
        return manual_slide_selection(web_content, source_url)
      end

      # Ask for general integration guidance
      integration_guidance = @prompt.multiline("Any specific guidance for how to integrate the content? (Press Enter twice when done, or leave blank for AI to decide)").join("\n")

      # Apply enhancements to the AI-selected slides
      slide_matches.each do |match|
        slide = @talk.slides[match[:slide_index]]

        puts "\n🔧 Enhancing: #{slide.title}".white

        begin
          update_prompt = <<~PROMPT
            Enhance this slide with relevant information from the web content:

            Current Slide:
            Title: #{slide.title}
            Content: #{slide.content.join(", ")}
            Current Notes: #{slide.notes}

            Web Content: #{web_content}
            Source URL: #{source_url}

            AI Analysis: #{match[:reason]}
            Suggested Enhancement: #{match[:enhancement]}
            Integration guidance: #{integration_guidance.empty? ? "Use AI judgment for best integration approach" : integration_guidance}

            Instructions:
            1. Keep the original slide structure and intent
            2. Add relevant information, examples, or data from the web content
            3. Focus on the suggested enhancement approach
            4. Maintain the slide's focus and clarity
            5. Include source attribution in speaker notes

            IMPORTANT: Respond ONLY with valid JSON in this format:
            {
              "title": "enhanced slide title (or keep original)",
              "content": ["enhanced content point 1", "enhanced content point 2", "etc"],
              "speaker_notes": "enhanced speaker notes with source attribution"
            }
          PROMPT

          response = ai_ask_with_spinner(update_prompt, message: "Enhancing slide with web content...")
          slide_data = parse_ai_json_response(response)

          if slide_data
            slide.title = slide_data["title"] if slide_data["title"]
            slide.content = slide_data["content"] if slide_data["content"]
            slide.notes = "#{slide_data["speaker_notes"] || slide.notes}\n\nSource: #{source_url}"

            puts "✅ Updated: #{slide.title}".green
          else
            puts "⚠️  Could not update slide: #{slide.title}".yellow
          end
        rescue StandardError => e
          puts "❌ Error updating slide #{slide.title}: #{e.message}".red
        end
      end

      auto_save
      puts "\n🎉 Updated #{slide_matches.length} slides with web content!".green.bold
    end

    def manual_slide_selection(web_content, source_url)
      puts "\n📝 Manual slide selection mode...".yellow

      # Show existing slides
      slide_choices = @talk.slides.map.with_index do |slide, index|
        { name: slide.display_summary, value: index }
      end

      selected_slides = @prompt.multi_select("Select slides to enhance with web content:", slide_choices)
      return if selected_slides.empty?

      # Ask for guidance
      integration_guidance = @prompt.multiline("How should the web content be integrated? (e.g., add examples, provide supporting data, etc.)").join("\n")

      selected_slides.each do |slide_index|
        slide = @talk.slides[slide_index]

        begin
          update_prompt = <<~PROMPT
            Enhance this slide with relevant information from the web content:

            Current Slide:
            Title: #{slide.title}
            Content: #{slide.content.join(", ")}
            Current Notes: #{slide.notes}

            Web Content: #{web_content}
            Source URL: #{source_url}

            Integration guidance: #{integration_guidance}

            Instructions:
            1. Keep the original slide structure and intent
            2. Add relevant information, examples, or data from the web content
            3. Maintain the slide's focus and clarity
            4. Include source attribution in speaker notes

            IMPORTANT: Respond ONLY with valid JSON in this format:
            {
              "title": "enhanced slide title (or keep original)",
              "content": ["enhanced content point 1", "enhanced content point 2", "etc"],
              "speaker_notes": "enhanced speaker notes with source attribution"
            }
          PROMPT

          response = ai_ask_with_spinner(update_prompt, message: "Enhancing slide with web content...")
          slide_data = parse_ai_json_response(response)

          if slide_data
            slide.title = slide_data["title"] if slide_data["title"]
            slide.content = slide_data["content"] if slide_data["content"]
            slide.notes = "#{slide_data["speaker_notes"] || slide.notes}\n\nSource: #{source_url}"

            puts "✅ Updated: #{slide.title}".green
          else
            puts "⚠️  Could not update slide: #{slide.title}".yellow
          end
        rescue StandardError => e
          puts "❌ Error updating slide #{slide.title}: #{e.message}".red
        end
      end

      auto_save
      puts "\n🎉 Updated #{selected_slides.length} slides with web content!".green.bold
    end

    def build_slide_matching_prompt(web_content, source_url)
      <<~PROMPT
        Analyze this web content and identify which existing slides would benefit most from this information:

        **Web Content from #{source_url}:**
        #{web_content}

        **Current Presentation:**
        Title: #{@talk.title}
        Description: #{@talk.description}
        Goal: #{@talk.target_audience}

        **Existing Slides:**
        #{@talk.slides.map.with_index(1) { |slide, i| "#{i}. #{slide.title}\n   Content: #{slide.content.join(", ")}\n   Current Notes: #{slide.notes}" }.join("\n\n")}

        **Analysis Task:**
        For each slide that would significantly benefit from this web content, provide:
        1. Why this slide is relevant to the web content
        2. How the web content could enhance the slide
        3. What specific enhancement approach would work best

        **Response Format:**
        For each relevant slide, respond with this format:

        SLIDE_MATCH: [slide_number]
        RELEVANCE: [High/Medium/Low]#{" "}
        REASON: [Explain why this slide matches the web content]
        ENHANCEMENT: [Specific suggestion for how to integrate the content]
        ---

        Only include slides with High or Medium relevance. If no slides are highly relevant, explain why and suggest what type of content would work better as new slides.

        Focus on slides where the web content provides:
        - Supporting examples or case studies
        - Additional data or statistics#{"  "}
        - Real-world applications
        - Technical details or explanations
        - Current trends or developments
      PROMPT
    end

    def parse_slide_matching_response(response)
      matches = []

      # Split response into slide matches
      slide_sections = response.split(/---+/).map(&:strip).reject(&:empty?)

      slide_sections.each do |section|
        lines = section.split("\n").map(&:strip)
        match_data = {}

        lines.each do |line|
          case line
          when /^SLIDE_MATCH:\s*(\d+)/i
            match_data[:slide_index] = ::Regexp.last_match(1).to_i - 1 # Convert to 0-based index
          when /^RELEVANCE:\s*(.+)/i
            match_data[:relevance] = ::Regexp.last_match(1).strip
          when /^REASON:\s*(.+)/i
            match_data[:reason] = ::Regexp.last_match(1).strip
          when /^ENHANCEMENT:\s*(.+)/i
            match_data[:enhancement] = ::Regexp.last_match(1).strip
          end
        end

        # Only include if we have all required fields and slide exists
        next unless match_data[:slide_index] &&
                    match_data[:slide_index] >= 0 &&
                    match_data[:slide_index] < @talk.slides.length &&
                    match_data[:relevance] &&
                    match_data[:reason] &&
                    match_data[:enhancement] &&
                    %w[High Medium].include?(match_data[:relevance])

        matches << match_data
      end

      # Sort by relevance (High first, then Medium)
      matches.sort_by { |match| match[:relevance] == "High" ? 0 : 1 }
    end

    def create_summary_slide(web_content, source_url)
      puts "\n📊 Creating summary slide from web content...".yellow

      # Ask for customization
      summary_focus = @prompt.ask("What should the summary focus on? (key points, statistics, quotes, etc.):",
                                  default: "key points and main insights")

      begin
        summary_prompt = <<~PROMPT
          Create a single summary slide from this web content:

          Source URL: #{source_url}
          Content: #{web_content}

          Presentation context:
          Title: #{@talk.title}
          Description: #{@talk.description}
          Target Audience: #{@talk.target_audience}

          Summary focus: #{summary_focus}

          Instructions:
          1. Create a compelling slide title
          2. Extract the most important #{summary_focus}
          3. Present information in 3-5 clear bullet points
          4. Include source attribution in speaker notes

          IMPORTANT: Respond ONLY with valid JSON in this format:
          {
            "title": "slide title",
            "content": ["point 1", "point 2", "point 3", "point 4", "point 5"],
            "speaker_notes": "detailed notes with source reference"
          }
        PROMPT

        response = ai_ask_with_spinner(summary_prompt, message: "Creating summary slide from web content...")
        slide_data = parse_ai_json_response(response)

        if slide_data
          position = @prompt.ask("Insert after which slide? (0 for beginning, #{@talk.slides.length} for end):",
                                 convert: :int, default: @talk.slides.length)
          position = [[position, 0].max, @talk.slides.length].min

          slide = Slide.new(
            title: slide_data["title"],
            content: slide_data["content"] || [],
            notes: "#{slide_data["speaker_notes"] || ""}\n\nSource: #{source_url}"
          )

          @talk.slides.insert(position, slide)

          # Renumber all slides
          # Slide numbers are now calculated dynamically
          auto_save

          puts "✅ Created summary slide: #{slide.title}".green
          puts "\n🎉 Web content successfully integrated!".green.bold
        else
          puts "❌ Failed to create summary slide".red
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}".red
      end
    end

    def ai_fix_mode
      puts "\n🔧 AI Fix Mode - Expand Your Presentation".cyan.bold
      puts "This mode helps you add multiple slides to reach the appropriate length for your talk.".white

      # Calculate recommended slide count
      recommended_slides = calculate_recommended_slides(@talk.duration_minutes)
      current_slides = @talk.slides.length

      puts "\n📊 Presentation Analysis:".yellow
      puts "   Duration: #{@talk.duration_minutes} minutes"
      puts "   Current slides: #{current_slides}"
      puts "   Recommended slides: #{recommended_slides} (at ~1-2 minutes per slide)"
      puts "   Suggested additions: #{[recommended_slides - current_slides, 0].max} more slides"

      if current_slides.zero?
        puts "\n⚠️  No slides yet. Please create some slides first.".yellow
        puts "   Use 'Create complete talk with AI' from the main menu.".white
        return
      end

      choice = @prompt.select("\nWhat would you like to do?", [
                                { name: "Add slides at specific positions", value: :add_at_positions },
                                { name: "Expand specific sections", value: :expand_sections },
                                { name: "Fill gaps between existing slides", value: :fill_gaps },
                                { name: "Generate complete slide set (#{recommended_slides} slides)",
                                  value: :complete_set },
                                { name: "Back to AI menu", value: :back }
                              ])

      case choice
      when :add_at_positions
        ai_add_slides_at_positions
      when :expand_sections
        ai_expand_sections
      when :fill_gaps
        ai_fill_gaps
      when :complete_set
        ai_generate_complete_set(recommended_slides)
      when :back
        nil
      end
    end

    def calculate_recommended_slides(duration_minutes)
      # General guideline: 1-2 minutes per slide for most presentations
      # For technical talks, might be closer to 1 minute per slide
      # For story-driven talks, might be 2-3 minutes per slide

      case duration_minutes
      when 0..10
        duration_minutes # ~1 slide per minute for short talks
      when 11..30
        (duration_minutes * 1.5).to_i  # ~1.5 slides per minute
      when 31..45
        (duration_minutes * 1.2).to_i  # ~1.2 slides per minute
      else
        (duration_minutes * 1.0).to_i  # ~1 slide per minute for longer talks
      end
    end

    def ai_add_slides_at_positions
      puts "\n📍 Add Slides at Specific Positions".white

      # Show current structure
      puts "\nCurrent slide structure:".bold
      @talk.slides.each_with_index do |slide, i|
        puts "#{i + 1}. #{slide.title}"
      end

      # Ask where to insert
      position = @prompt.ask("\nInsert after which slide? (0 for beginning):", convert: :int)

      if position.negative? || position > @talk.slides.length
        puts "❌ Invalid position".red
        return
      end

      # Ask how many slides
      count = @prompt.ask("How many slides to add?", convert: :int, default: 3)

      # Ask for specific context
      context = @prompt.multiline("What should these slides cover? (Press Enter twice when done)").join("\n")

      puts "\n🤖 Generating #{count} slides...".yellow

      begin
        # Prepare context about surrounding slides
        before_slide = position.positive? ? @talk.slides[position - 1] : nil
        after_slide = position < @talk.slides.length ? @talk.slides[position] : nil

        slides_prompt = <<~PROMPT
          Create #{count} slides for this presentation:
          Title: #{@talk.title}
          Description: #{@talk.description}

          These slides should cover: #{context}

          #{before_slide ? "Previous slide: #{before_slide.title}" : "These will be the first slides"}
          #{after_slide ? "Next slide: #{after_slide.title}" : "These will be the last slides"}

          Create a smooth transition between existing slides.

          IMPORTANT: Respond ONLY with valid JSON in this format:
          {
            "slides": [
              {
                "title": "slide title",
                "content": ["point 1", "point 2", "point 3"],
                "speaker_notes": "detailed speaker notes"
              }
            ]
          }
        PROMPT

        response = ai_ask_with_spinner(slides_prompt, message: "Generating #{count} slides...")
        slides_data = parse_ai_json_response(response)

        if slides_data && slides_data["slides"]
          # Insert slides in reverse order to maintain position
          slides_data["slides"].reverse.each do |slide_data|
            slide = Slide.new(
              title: slide_data["title"],
              content: slide_data["content"] || [],
              notes: slide_data["speaker_notes"] || ""
            )
            @talk.slides.insert(position, slide)
            puts "✅ Added: #{slide.title}".green
          end

          # Renumber all slides
          # Slide numbers are now calculated dynamically

          auto_save
          puts "\n🎉 Added #{slides_data["slides"].length} slides successfully!".green
        else
          puts "❌ Failed to generate slides".red
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}".red
      end
    end

    def ai_expand_sections
      puts "\n📈 Expand Specific Sections".white

      # Group slides into sections
      puts "\nWhich section needs expansion?".bold

      slide_choices = @talk.slides.map.with_index do |slide, i|
        { name: "#{i + 1}. #{slide.title}", value: i }
      end

      section_start = @prompt.select("Select the slide that starts the section:", slide_choices)
      section_end = @prompt.select("Select the slide that ends the section:",
                                   slide_choices.select { |c| c[:value] >= section_start })

      section_slides = @talk.slides[section_start..section_end]

      puts "\n📋 Section to expand:".yellow
      section_slides.each { |s| puts "   • #{s.title}" }

      expansion_count = @prompt.ask("How many slides to add to this section?", convert: :int, default: 3)

      puts "\n🤖 Analyzing section and generating expansion...".yellow

      begin
        expansion_prompt = <<~PROMPT
          Expand this section of the presentation:

          Presentation: #{@talk.title}
          Description: #{@talk.description}

          Current section slides:
          #{section_slides.map { |s| "- #{s.title}: #{s.content.join(", ")}" }.join("\n")}

          Add #{expansion_count} slides that:
          1. Provide more detail and depth
          2. Add examples or case studies
          3. Include practical applications
          4. Maintain the section's focus

          IMPORTANT: Respond ONLY with valid JSON in this format:
          {
            "slides": [
              {
                "title": "slide title",
                "content": ["point 1", "point 2", "point 3"],
                "speaker_notes": "detailed speaker notes",
                "insert_after": "title of existing slide to insert after"
              }
            ]
          }
        PROMPT

        response = ai_ask_with_spinner(expansion_prompt, message: "Analyzing section and generating expansion...")
        slides_data = parse_ai_json_response(response)

        if slides_data && slides_data["slides"]
          slides_data["slides"].each do |slide_data|
            # Find insertion point
            insert_position = section_end + 1
            if slide_data["insert_after"]
              @talk.slides.each_with_index do |s, i|
                if s.title.downcase.include?(slide_data["insert_after"].downcase)
                  insert_position = i + 1
                  break
                end
              end
            end

            slide = Slide.new(
              title: slide_data["title"],
              content: slide_data["content"] || [],
              notes: slide_data["speaker_notes"] || ""
            )

            @talk.slides.insert(insert_position, slide)
            puts "✅ Added: #{slide.title} (position #{insert_position + 1})".green
          end

          # Renumber all slides
          # Slide numbers are now calculated dynamically

          auto_save
          puts "\n🎉 Section expanded successfully!".green
        else
          puts "❌ Failed to expand section".red
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}".red
      end
    end

    def ai_fill_gaps
      puts "\n🔗 Fill Gaps Between Slides".white

      # Identify potential gaps
      gaps = []
      @talk.slides.each_cons(2).with_index do |(slide1, slide2), i|
        puts "#{i + 1}. Between: \"#{slide1.title}\" → \"#{slide2.title}\""
        gaps << { from: i, to: i + 1, slide1: slide1, slide2: slide2 }
      end

      if gaps.empty?
        puts "No gaps to fill (need at least 2 slides)".yellow
        return
      end

      gap_choices = gaps.map.with_index do |gap, i|
        {
          name: "Between slides #{gap[:from] + 1} and #{gap[:to] + 1}",
          value: i
        }
      end

      selected_gaps = @prompt.multi_select("Select gaps to fill:", gap_choices)

      return if selected_gaps.empty?

      puts "\n🤖 Analyzing transitions and generating bridge slides...".yellow

      selected_gaps.each do |gap_index|
        gap = gaps[gap_index]

        begin
          bridge_prompt = <<~PROMPT
            Create 1-3 bridge slides to smoothly transition between these slides:

            From: "#{gap[:slide1].title}"
            Content: #{gap[:slide1].content.join(", ")}

            To: "#{gap[:slide2].title}"
            Content: #{gap[:slide2].content.join(", ")}

            Presentation context:
            Title: #{@talk.title}
            Description: #{@talk.description}

            The bridge slides should:
            1. Create a logical flow between topics
            2. Introduce concepts needed for the next slide
            3. Summarize or conclude the previous topic if needed

            IMPORTANT: Respond ONLY with valid JSON in this format:
            {
              "slides": [
                {
                  "title": "slide title",
                  "content": ["point 1", "point 2", "point 3"],
                  "speaker_notes": "transition notes"
                }
              ]
            }
          PROMPT

          response = ai_ask_with_spinner(bridge_prompt,
                                         message: "Analyzing transitions and generating bridge slides...")
          slides_data = parse_ai_json_response(response)

          if slides_data && slides_data["slides"]
            # Insert after the first slide of the gap
            insert_position = gap[:to]

            slides_data["slides"].each_with_index do |slide_data, i|
              slide = Slide.new(
                title: slide_data["title"],
                content: slide_data["content"] || [],
                notes: slide_data["speaker_notes"] || ""
              )

              @talk.slides.insert(insert_position + i, slide)
              puts "✅ Added bridge: #{slide.title}".green
            end
          end
        rescue StandardError => e
          puts "❌ Error filling gap: #{e.message}".red
        end
      end

      # Renumber all slides
      @talk.slides.each_with_index { |s, i| s.number = i + 1 }

      auto_save
      puts "\n🎉 Gaps filled successfully!".green
    end

    def ai_generate_complete_set(target_count)
      current_count = @talk.slides.length

      if current_count >= target_count
        puts "✅ You already have #{current_count} slides (target: #{target_count})".green
        return
      end

      puts "\n🚀 Generating Complete Slide Set".white
      puts "Current: #{current_count} slides → Target: #{target_count} slides".white

      return unless @prompt.yes?("\nThis will add #{target_count - current_count} slides. Continue?")

      puts "\n🤖 Analyzing presentation structure and generating complete slide set...".yellow

      begin
        complete_prompt = <<~PROMPT
          Expand this presentation to #{target_count} total slides:

          Title: #{@talk.title}
          Description: #{@talk.description}
          Duration: #{@talk.duration_minutes} minutes
          Audience: #{@talk.target_audience}

          Current slides (#{current_count}):
          #{@talk.slides.map.with_index { |s, i| "#{i + 1}. #{s.title}" }.join("\n")}

          Generate #{target_count - current_count} additional slides that:
          1. Expand on existing topics with more detail
          2. Add examples, case studies, and practical applications
          3. Include interactive elements (polls, Q&A, exercises)
          4. Add transition and summary slides
          5. Ensure proper pacing for a #{@talk.duration_minutes}-minute presentation

          Structure suggestions:
          - Introduction (2-3 slides)
          - Main content sections (with examples and deep dives)
          - Interactive breaks every 10-15 minutes
          - Recap/summary slides between major sections
          - Strong conclusion (2-3 slides)
          - Q&A preparation

          IMPORTANT: Respond ONLY with valid JSON in this format:
          {
            "slides": [
              {
                "title": "slide title",
                "content": ["point 1", "point 2", "point 3"],
                "speaker_notes": "detailed notes",
                "position": "after_slide_X" or "end"
              }
            ]
          }
        PROMPT

        response = ai_ask_with_spinner(complete_prompt, message: "Generating complete slide set...")
        slides_data = parse_ai_json_response(response)

        if slides_data && slides_data["slides"]
          added_count = 0

          slides_data["slides"].each do |slide_data|
            slide = Slide.new(
              title: slide_data["title"],
              content: slide_data["content"] || [],
              notes: slide_data["speaker_notes"] || ""
            )

            # Determine position
            if slide_data["position"] == "end"
              @talk.slides << slide
            elsif slide_data["position"]&.start_with?("after_slide_")
              position = slide_data["position"].sub("after_slide_", "").to_i
              position = [position, @talk.slides.length].min
              @talk.slides.insert(position, slide)
            else
              @talk.slides << slide
            end

            added_count += 1
            puts "✅ Added: #{slide.title}".green

            # Show progress
            if (added_count % 5).zero?
              puts "   Progress: #{added_count}/#{target_count - current_count} slides added...".white
            end
          end

          # Renumber all slides
          # Slide numbers are now calculated dynamically

          auto_save

          puts "\n🎉 Presentation expanded to #{@talk.slides.length} slides!".green.bold
          puts "   Ready for a #{@talk.duration_minutes}-minute presentation".white

          show_talk_overview if @prompt.yes?("\nWould you like to review the new structure?")
        else
          puts "❌ Failed to generate complete slide set".red
        end
      rescue StandardError => e
        puts "❌ Error: #{e.message}".red
      end
    end

    def fact_check_slides
      unless @serper_client.available?
        puts "\n❌ Fact-checking unavailable: Serper API key not configured.".red
        return unless @prompt.yes?("Would you like to set up the API key now?")

        setup_serper_key
        return unless @serper_client.available?

      end

      return puts "No slides to fact-check yet.".yellow if @talk.slides.empty?

      puts "\n🔍 Fact-Check Slides".cyan.bold
      puts "AI will verify claims in your slides using Google search and web sources.".white

      # Option to check all slides or select specific ones
      check_mode = @prompt.select("What would you like to fact-check?", [
                                    { name: "All slides", value: :all },
                                    { name: "Specific slides", value: :specific },
                                    { name: "Current slide with most claims", value: :priority }
                                  ])

      slides_to_check = case check_mode
                        when :all
                          Array(0...@talk.slides.length)
                        when :specific
                          select_slides_for_fact_checking
                        when :priority
                          [find_slide_with_most_claims]
                        end

      return if slides_to_check.empty?

      puts "\n📊 Starting fact-check process...".yellow
      fact_check_results = []

      slides_to_check.each_with_index do |slide_index, _i|
        slide = @talk.slides[slide_index]
        puts "\n📍 Checking slide #{slide_index + 1}/#{@talk.slides.length}: #{slide.title}".white

        # Step 1: Extract claims from the slide
        claims = extract_claims_from_slide(slide)

        if claims.empty?
          puts "   ⚠️  No verifiable claims found in this slide".yellow
          next
        end

        puts "   Found #{claims.length} claims to verify...".white

        # Step 2: Search for each claim using Serper
        search_results = search_claims_with_serper(claims)

        # Step 3: Fetch additional web content for verification
        web_evidence = fetch_web_evidence(search_results)

        # Step 4: AI analyzes all evidence and provides verdict
        fact_check_result = analyze_claims_with_ai(slide, claims, search_results, web_evidence)

        # Extract URLs for transparency
        checked_urls = extract_urls_from_search_results(search_results)
        web_evidence.each do |evidence|
          checked_urls << {
            title: evidence[:source_title],
            url: evidence[:source_url],
            type: "Web Content"
          }
        end

        fact_check_results << {
          slide: slide,
          slide_index: slide_index,
          claims: claims,
          result: fact_check_result,
          checked_urls: checked_urls,
          web_evidence: web_evidence
        }

        # Display results for this slide
        display_fact_check_result(slide, fact_check_result, checked_urls, web_evidence)
      end

      # Summary and action options
      display_fact_check_summary(fact_check_results)
    end

    def select_slides_for_fact_checking
      slide_choices = @talk.slides.map.with_index do |slide, index|
        { name: slide.display_summary, value: index }
      end

      @prompt.multi_select("Select slides to fact-check:", slide_choices)
    end

    def find_slide_with_most_claims
      # Find slide with most factual claims (heuristic: numbers, dates, names, statistics)
      scored_slides = @talk.slides.map.with_index do |slide, index|
        content_text = "#{slide.title} #{slide.content.join(" ")} #{slide.notes}"

        # Simple scoring based on potential fact patterns
        score = 0
        score += content_text.scan(/\d{4}/).length * 2  # Years
        score += content_text.scan(/\d+%/).length * 3   # Percentages
        score += content_text.scan(/\$\d+/).length * 2  # Money amounts
        score += content_text.scan(/\d+\s*(million|billion|thousand)/).length * 3 # Large numbers
        score += content_text.scan(/according to|research shows|study found|data indicates/i).length * 4 # Research claims

        [index, score]
      end

      scored_slides.max_by { |_, score| score }[0]
    end

    def extract_claims_from_slide(slide)
      puts "   🔍 Extracting verifiable claims...".white

      extraction_prompt = <<~PROMPT
        Extract verifiable factual claims from this slide content:

        Title: #{slide.title}
        Content: #{slide.content.join("\n")}
        Notes: #{slide.notes}

        Identify specific claims that can be fact-checked, such as:
        - Statistics and percentages
        - Historical facts and dates
        - Company information and figures
        - Technical specifications
        - Research findings and studies
        - Market data and trends

        For each claim, provide:
        1. The exact claim statement
        2. Why it's verifiable
        3. What type of sources would verify it

        Format as a numbered list. Only include claims that are specific and verifiable.
        Ignore opinions, subjective statements, and general concepts.
      PROMPT

      response = ai_ask_with_spinner(extraction_prompt, message: "Extracting factual claims...")

      if response && !response.strip.empty?
        # Parse the AI response to extract individual claims
        claims = response.split(/\n\d+\./).map(&:strip).reject(&:empty?)
        claims = claims.map { |claim| claim.gsub(/^\d+\.\s*/, "") }

        # Filter and clean claims
        claims.select { |claim| claim.length > 10 && claim.length < 200 }
      else
        []
      end
    end

    def search_claims_with_serper(claims)
      puts "   🌐 Searching Google for verification...".white

      search_results = []

      claims.each_with_index do |claim, i|
        puts "     Claim #{i + 1}: #{claim[0..50]}...".white

        result = @serper_client.search_for_fact_checking([claim])
        search_results.concat(result) if result.any?

        # Rate limiting
        sleep(0.5) if i < claims.length - 1
      end

      search_results
    end

    def fetch_web_evidence(search_results)
      puts "   📄 Fetching web evidence...".white

      web_evidence = []
      web_fetcher = WebContentFetcher.new

      # Get content from top search results
      search_results.each do |search_result|
        # Take top 2 organic results for each search
        search_result[:search_results][:organic_results]&.first(2)&.each do |result|
          content_result = web_fetcher.fetch_content(result[:link])

          if content_result[:success]
            web_evidence << {
              claim: search_result[:claim],
              source_url: result[:link],
              source_title: result[:title],
              content: content_result[:content][0..1500] # Limit content length
            }
          end

          # Limit total web fetches to avoid overwhelming
          break if web_evidence.length >= 6
        end

        break if web_evidence.length >= 6
      end

      web_evidence
    end

    def analyze_claims_with_ai(slide, claims, search_results, web_evidence)
      puts "   🤖 AI analyzing evidence...".white

      analysis_prompt = build_fact_check_analysis_prompt(slide, claims, search_results, web_evidence)

      analysis_result = ai_ask_with_spinner(analysis_prompt, message: "Analyzing fact-check evidence...")

      if analysis_result
        parse_fact_check_analysis(analysis_result)
      else
        {
          overall_verdict: "Unable to verify",
          claim_verdicts: [],
          summary: "AI analysis failed",
          recommendations: []
        }
      end
    end

    def build_fact_check_analysis_prompt(slide, claims, search_results, web_evidence)
      <<~PROMPT
        Fact-check these claims from a presentation slide using the provided evidence:

        **Slide Information:**
        Title: #{slide.title}
        Content: #{slide.content.join("\n")}

        **Claims to Verify:**
        #{claims.map.with_index(1) { |claim, i| "#{i}. #{claim}" }.join("\n")}

        **Google Search Results:**
        #{format_search_results_for_analysis(search_results)}

        **Web Evidence:**
        #{format_web_evidence_for_analysis(web_evidence)}

        **Analysis Task:**
        For each claim, determine:
        1. VERDICT: "Verified", "Partially Verified", "Contradicted", or "Insufficient Evidence"
        2. CONFIDENCE: "High", "Medium", or "Low"
        3. EVIDENCE: Key supporting or contradicting evidence
        4. SOURCES: Most reliable sources found

        **Response Format:**
        Provide analysis in this structure:

        OVERALL_VERDICT: [Overall assessment of slide accuracy]

        CLAIM_ANALYSIS:
        Claim 1: [First claim]
        Verdict: [Verified/Partially Verified/Contradicted/Insufficient Evidence]
        Confidence: [High/Medium/Low]
        Evidence: [Key evidence summary]
        Sources: [Most reliable sources]

        [Repeat for each claim]

        RECOMMENDATIONS:
        - [Specific suggestions for improving accuracy]
        - [Sources to cite or verify]
        - [Claims that need updating]

        SUMMARY: [Brief overall assessment and key findings]
      PROMPT
    end

    def format_search_results_for_analysis(search_results)
      formatted = []

      search_results.each do |result|
        formatted << "Claim: #{result[:claim]}"

        if result[:search_results][:knowledge_graph]
          kg = result[:search_results][:knowledge_graph]
          formatted << "  Knowledge Graph: #{kg[:title]} - #{kg[:description]}"
          formatted << "    URL: #{kg[:website]}" if kg[:website]
        end

        result[:search_results][:organic_results]&.first(3)&.each do |organic|
          formatted << "  Result: #{organic[:title]} - #{organic[:snippet]}"
          formatted << "    URL: #{organic[:link]}" if organic[:link]
        end

        formatted << ""
      end

      formatted.join("\n")
    end

    def format_web_evidence_for_analysis(web_evidence)
      web_evidence.map do |evidence|
        "Source: #{evidence[:source_title]} (#{evidence[:source_url]})\n" \
          "Content: #{evidence[:content][0..500]}...\n"
      end.join("\n")
    end

    def parse_fact_check_analysis(analysis_text)
      result = {
        overall_verdict: "Unknown",
        claim_verdicts: [],
        recommendations: [],
        summary: ""
      }

      # Extract overall verdict
      if (match = analysis_text.match(/OVERALL_VERDICT:\s*(.+?)$/m))
        result[:overall_verdict] = match[1].strip
      end

      # Extract claim analyses
      claim_sections = analysis_text.split(/CLAIM_ANALYSIS:|Claim \d+:/).drop(1)
      claim_sections.each do |section|
        claim_verdict = {}

        if (match = section.match(/Verdict:\s*(.+?)$/m))
          claim_verdict[:verdict] = match[1].strip
        end

        if (match = section.match(/Confidence:\s*(.+?)$/m))
          claim_verdict[:confidence] = match[1].strip
        end

        if (match = section.match(/Evidence:\s*(.+?)(?=Sources:|RECOMMENDATIONS:|$)/m))
          claim_verdict[:evidence] = match[1].strip
        end

        if (match = section.match(/Sources:\s*(.+?)(?=RECOMMENDATIONS:|$)/m))
          claim_verdict[:sources] = match[1].strip
        end

        result[:claim_verdicts] << claim_verdict if claim_verdict.any?
      end

      # Extract recommendations
      if (match = analysis_text.match(/RECOMMENDATIONS:\s*(.+?)(?=SUMMARY:|$)/m))
        recommendations_text = match[1].strip
        result[:recommendations] = recommendations_text.split(/\n-\s*/).map(&:strip).reject(&:empty?)
      end

      # Extract summary
      if (match = analysis_text.match(/SUMMARY:\s*(.+?)$/m))
        result[:summary] = match[1].strip
      end

      result
    end

    def extract_urls_from_search_results(search_results)
      urls = []

      search_results.each do |result|
        # Knowledge graph URLs
        if result[:search_results][:knowledge_graph]&.dig(:website)
          urls << {
            title: result[:search_results][:knowledge_graph][:title],
            url: result[:search_results][:knowledge_graph][:website],
            type: "Knowledge Graph"
          }
        end

        # Organic search result URLs
        result[:search_results][:organic_results]&.first(3)&.each do |organic|
          urls << {
            title: organic[:title],
            url: organic[:link],
            type: "Search Result"
          }
        end
      end

      urls.compact
    end

    def build_slide_improvement_prompt(slide, fact_check_result, checked_urls, web_evidence)
      <<~PROMPT
        You are helping improve a presentation slide based on fact-checking results.

        SLIDE INFORMATION:
        Title: #{slide.title}
        Content: #{slide.content.join(", ")}
        Speaker Notes: #{slide.notes || "None"}

        FACT-CHECK RESULTS:
        Overall Verdict: #{fact_check_result[:overall_verdict]}
        Summary: #{fact_check_result[:summary]}

        SOURCES CHECKED:
        #{checked_urls.map { |url| "• #{url[:title]} - #{url[:url]}" }.join("\n")}

        WEB EVIDENCE:
        #{format_web_evidence_for_analysis(web_evidence)}

        RECOMMENDATIONS:
        #{fact_check_result[:recommendations].map { |rec| "• #{rec}" }.join("\n")}

        Please provide an improved version of this slide that:
        1. Addresses fact-checking concerns and recommendations
        2. Updates any inaccurate claims with verified information
        3. Adds credible sources where appropriate
        4. Maintains the slide's educational value and flow
        5. Includes citations in speaker notes

        Respond with a JSON object in this format:
        {
          "improved_title": "Updated slide title if needed",
          "improved_content": ["Updated bullet point 1", "Updated bullet point 2", ...],
          "improved_notes": "Updated speaker notes with citations and explanations",
          "changes_made": ["Description of change 1", "Description of change 2", ...],
          "confidence": "High/Medium/Low - your confidence in these improvements"
        }
      PROMPT
    end

    def display_fact_check_result(slide, result, checked_urls = [], _web_evidence = [])
      puts "\n   📊 Fact-Check Results for: #{slide.title}".white.bold

      # Overall verdict with color coding
      verdict_color = case result[:overall_verdict].downcase
                      when /verified/ then :green
                      when /contradicted/ then :red
                      when /partially/ then :yellow
                      else :light_blue
                      end

      puts "   Overall: #{result[:overall_verdict]}".send(verdict_color)

      # Individual claim results
      if result[:claim_verdicts].any?
        puts "\n   📋 Individual Claims:".bold
        result[:claim_verdicts].each_with_index do |claim_result, i|
          verdict_symbol = case claim_result[:verdict]&.downcase
                           when /verified/ then "✅"
                           when /contradicted/ then "❌"
                           when /partially/ then "⚠️"
                           else "❓"
                           end

          puts "   #{verdict_symbol} Claim #{i + 1}: #{claim_result[:verdict]} (#{claim_result[:confidence]} confidence)"
          puts "     Evidence: #{claim_result[:evidence]}" if claim_result[:evidence]
          puts "     Sources: #{claim_result[:sources]}" if claim_result[:sources]
        end
      end

      # Recommendations
      if result[:recommendations].any?
        puts "\n   💡 Recommendations:".white
        result[:recommendations].each do |rec|
          puts "   • #{rec}"
        end
      end

      # Display checked URLs for transparency
      if checked_urls.any?
        puts "\n   🔗 Sources Checked:".white
        checked_urls.first(5).each do |url_info|
          puts "   • #{url_info[:title]}"
          puts "     #{url_info[:url]}".light_black
        end
        puts "   ... and #{checked_urls.length - 5} more sources".light_black if checked_urls.length > 5
      end

      puts "\n   📝 Summary: #{result[:summary]}".white if result[:summary]
    end

    def display_fact_check_summary(results)
      return if results.empty?

      puts "\n#{"=" * 60}"
      puts "🔍 FACT-CHECK SUMMARY".cyan.bold
      puts "=" * 60

      verified_count = 0
      contradicted_count = 0
      partial_count = 0

      results.each do |result|
        slide_name = result[:slide].title
        verdict = result[:result][:overall_verdict]

        case verdict.downcase
        when /verified/ then verified_count += 1
        when /contradicted/ then contradicted_count += 1
        when /partially/ then partial_count += 1
        end

        verdict_symbol = case verdict.downcase
                         when /verified/ then "✅"
                         when /contradicted/ then "❌"
                         when /partially/ then "⚠️"
                         else "❓"
                         end

        puts "#{verdict_symbol} #{slide_name}: #{verdict}"
      end

      puts "\n📊 Overall Statistics:"
      puts "   ✅ Verified: #{verified_count} slides"
      puts "   ⚠️  Partially verified: #{partial_count} slides"
      puts "   ❌ Issues found: #{contradicted_count} slides"

      if contradicted_count.positive? || partial_count.positive?
        puts "\n💡 Next Steps:"
        puts "   • Review slides with issues or partial verification"
        puts "   • Update claims based on fact-check recommendations"
        puts "   • Add citations for verified claims to boost credibility"

        review_problematic_slides(results) if @prompt.yes?("\nWould you like to review and fix problematic slides?")
      else
        puts "\n🎉 Great! Your presentation appears to be factually accurate."
      end
    end

    def review_problematic_slides(results)
      problematic_slides = results.select do |result|
        verdict = result[:result][:overall_verdict].downcase
        verdict.include?("contradicted") || verdict.include?("partially")
      end

      return if problematic_slides.empty?

      puts "\n🔧 Reviewing Problematic Slides".yellow.bold

      problematic_slides.each do |slide_result|
        slide = slide_result[:slide]
        puts "\n📍 Reviewing: #{slide.title}".white

        display_fact_check_result(slide, slide_result[:result], slide_result[:checked_urls],
                                  slide_result[:web_evidence])

        action = @prompt.select("What would you like to do with this slide?", [
                                  { name: "🤖 Let AI improve this slide based on fact-check", value: :ai_improve },
                                  { name: "✏️  Edit slide manually", value: :edit },
                                  { name: "📝 Add citation notes", value: :cite },
                                  { name: "⏭️  Skip for now", value: :skip },
                                  { name: "➡️  Continue to next slide", value: :next }
                                ])

        case action
        when :ai_improve
          improve_slide_with_ai(slide, slide_result[:result], slide_result[:checked_urls], slide_result[:web_evidence])
        when :edit
          edit_slide(slide)
        when :cite
          add_citation_notes(slide, slide_result[:result])
        when :skip, :next
          next
        end
      end
    end

    def add_citation_notes(slide, fact_check_result)
      puts "\n📚 Adding citation suggestions to speaker notes...".white

      citation_notes = "\n\n--- FACT-CHECK CITATIONS ---\n"
      citation_notes += "Fact-checked on #{Time.now.strftime("%Y-%m-%d")}\n"
      citation_notes += "Overall verdict: #{fact_check_result[:overall_verdict]}\n\n"

      if fact_check_result[:claim_verdicts].any?
        citation_notes += "Sources to verify:\n"
        fact_check_result[:claim_verdicts].each_with_index do |claim, i|
          citation_notes += "#{i + 1}. #{claim[:sources]}\n" if claim[:sources]
        end
      end

      if fact_check_result[:recommendations].any?
        citation_notes += "\nRecommendations:\n"
        fact_check_result[:recommendations].each do |rec|
          citation_notes += "• #{rec}\n"
        end
      end

      slide.notes = (slide.notes || "") + citation_notes
      auto_save

      puts "✅ Citation notes added to slide".green
    end

    def improve_slide_with_ai(slide, fact_check_result, checked_urls, web_evidence)
      puts "\n🤖 AI improving slide based on fact-check results...".white

      improvement_prompt = build_slide_improvement_prompt(slide, fact_check_result, checked_urls, web_evidence)

      improvement_response = ai_ask_with_spinner(improvement_prompt, message: "Generating slide improvements...")

      unless improvement_response
        puts "❌ Could not get AI improvement suggestions".red
        return
      end

      improvement_data = parse_ai_json_response(improvement_response)

      unless improvement_data
        puts "❌ Could not parse AI improvement suggestions".red
        puts "Raw response: #{improvement_response[0..200]}...".light_black
        return
      end

      # Display proposed changes
      puts "\n🔍 Proposed Improvements:".green.bold
      puts "📝 Title: #{improvement_data["improved_title"]}" if improvement_data["improved_title"] != slide.title

      puts "\n📋 Updated Content:"
      improvement_data["improved_content"]&.each_with_index do |point, i|
        puts "   #{i + 1}. #{point}"
      end

      puts "\n📄 Updated Notes:" if improvement_data["improved_notes"]
      puts "   #{improvement_data["improved_notes"][0..200]}...".white

      if improvement_data["changes_made"]&.any?
        puts "\n🔄 Changes Made:".yellow
        improvement_data["changes_made"].each do |change|
          puts "   • #{change}"
        end
      end

      puts "\n🎯 AI Confidence: #{improvement_data["confidence"]}".white

      # Ask user to confirm changes
      if @prompt.yes?("\nApply these improvements to the slide?")
        # Apply improvements
        slide.title = improvement_data["improved_title"] if improvement_data["improved_title"]
        slide.content = improvement_data["improved_content"] if improvement_data["improved_content"]
        slide.notes = improvement_data["improved_notes"] if improvement_data["improved_notes"]

        auto_save
        puts "✅ Slide improved successfully!".green

        # Ask if user wants to re-run fact-check on improved slide
        if @prompt.yes?("Re-run fact-check on the improved slide?")
          puts "\n🔄 Re-checking improved slide...".white

          # Re-run fact-check on the improved slide
          claims = extract_claims_from_slide(slide)
          if claims.any?
            search_results = search_claims_with_serper(claims)
            web_evidence = fetch_web_evidence(search_results)
            fact_check_result = analyze_claims_with_ai(slide, claims, search_results, web_evidence)
            checked_urls = extract_urls_from_search_results(search_results)

            puts "\n🎉 Updated Fact-Check Results:".green.bold
            display_fact_check_result(slide, fact_check_result, checked_urls, web_evidence)
          end
        end
      else
        puts "⏭️  Improvements not applied".yellow
      end
    end

    def parse_ai_json_response(response)
      return nil unless response

      # Try to extract JSON from the response
      json_content = extract_json_from_response(response)
      return nil unless json_content

      # Try parsing the extracted JSON
      begin
        JSON.parse(json_content)
      rescue JSON::ParserError => e
        puts "⚠️  JSON parsing error: #{e.message}".yellow
        puts "   Attempting AI-assisted JSON correction...".white

        # Try to fix the JSON using AI
        corrected_json = fix_malformed_json_with_ai(json_content, e.message)

        if corrected_json
          begin
            result = JSON.parse(corrected_json)
            puts "   ✅ JSON correction successful!".green
            return result
          rescue JSON::ParserError => e2
            puts "   ❌ AI correction failed: #{e2.message}".red
          end
        end

        # Final fallback: try simple fixes
        puts "   Trying simple automatic fixes...".white
        simple_fixed = apply_simple_json_fixes(json_content)

        if simple_fixed
          begin
            result = JSON.parse(simple_fixed)
            puts "   ✅ Simple fix successful!".green
            return result
          rescue JSON::ParserError
            puts "   ❌ All JSON correction attempts failed".red
          end
        end

        nil
      end
    end

    def extract_json_from_response(response)
      return nil unless response.include?("{") && response.include?("}")

      start_index = response.index("{")
      bracket_count = 0
      end_index = start_index

      response[start_index..].each_char.with_index(start_index) do |char, i|
        bracket_count += 1 if char == "{"
        bracket_count -= 1 if char == "}"
        if bracket_count.zero?
          end_index = i
          break
        end
      end

      response[start_index..end_index]
    end

    def fix_malformed_json_with_ai(malformed_json, error_message)
      return nil unless @ai_available

      correction_prompt = <<~PROMPT
        The following JSON is malformed and needs to be corrected:

        ERROR: #{error_message}

        MALFORMED JSON:
        #{malformed_json}

        Please provide a corrected version that:
        1. Fixes the syntax error
        2. Preserves all the original data
        3. Maintains the same structure
        4. Is valid JSON

        IMPORTANT: Respond with ONLY the corrected JSON, no explanations or additional text.
      PROMPT

      begin
        response = ai_ask(correction_prompt)
        return nil unless response

        # Extract JSON from the correction response
        corrected = extract_json_from_response(response)

        # If no JSON brackets found, assume the entire response is JSON
        corrected || response.strip
      rescue StandardError => e
        puts "   ⚠️  AI correction request failed: #{e.message}".yellow
        nil
      end
    end

    def apply_simple_json_fixes(json_content)
      # Common JSON fixes
      fixed = json_content.dup

      # Fix trailing commas in arrays and objects
      fixed.gsub!(/,(\s*[}\]])/, '\1')

      # Fix missing commas between array elements
      fixed.gsub!(/("\s*)\s*\n\s*("|\{)/, '\1,\2')

      # Fix missing commas between object properties
      fixed.gsub!(/("\s*)\s*\n\s*"/, '\1,"')

      # Fix unquoted property names
      fixed.gsub!(/(\s*)([a-zA-Z_][a-zA-Z0-9_]*):/, '\1"\2":')

      # Fix single quotes to double quotes
      fixed.gsub!(/'([^']*)'/, '"\1"')

      # Remove comments (// and /* */)
      fixed.gsub!(%r{//.*$}, "")
      fixed.gsub!(%r{/\*.*?\*/}m, "")

      # Fix common Unicode issues
      fixed.gsub!(/["]/, '"')
      fixed.gsub!(/[']/, "'")

      fixed.strip
    end

    def export_talk
      formats = [
        { name: "Markdown (.md)", value: :markdown },
        { name: "Slidev presentation (.md)", value: :slidev },
        { name: "Plain text (.txt)", value: :text },
        { name: "JSON (.json)", value: :json },
      ]

      format = @prompt.select("Export format:", formats)
      filename = @prompt.ask("Enter filename (without extension):",
                             default: @talk.title.downcase.gsub(/[^a-z0-9]/, "_"))

      case format
      when :markdown
        export_markdown("#{filename}.md")
      when :slidev
        export_slidev("#{filename}.md")
      when :text
        export_text("#{filename}.txt")
      when :json
        @talk.save_to_file("#{filename}.json")
      end

      puts "✅ Talk exported successfully!".green
    end

    def export_markdown(filename)
      content = "# #{@talk.title}\n\n"
      content += "**Description:** #{@talk.description}\n\n"
      content += "**Target Audience:** #{@talk.target_audience}\n\n"
      content += "**Duration:** #{@talk.duration_minutes} minutes\n\n"
      content += "---\n\n"

      @talk.slides.each do |slide|
        content += "## #{slide.title}\n\n"
        slide.content.each { |point| content += "- #{point}\n" }
        content += "\n#{slide.notes}\n\n" unless slide.notes.strip.empty?
        content += "---\n\n"
      end

      File.write(filename, content)
    end

    def export_text(filename)
      content = "#{@talk.title}\n"
      content += "#{"=" * @talk.title.length}\n\n"
      content += "Description: #{@talk.description}\n"
      content += "Target Audience: #{@talk.target_audience}\n"
      content += "Duration: #{@talk.duration_minutes} minutes\n\n"

      @talk.slides.each_with_index do |slide, index|
        content += "#{index + 1}. #{slide.title}\n"
        content += "#{"-" * (slide.title.length + 3)}\n"
        slide.content.each { |point| content += "• #{point}\n" }
        content += "\nNotes: #{slide.notes}\n" unless slide.notes.strip.empty?
        content += "\n"
      end

      File.write(filename, content)
    end

    def export_slidev(filename)
      # Slidev front matter
      content = <<~SLIDEV
        ---
        theme: default
        title: "#{@talk.title}"
        titleTemplate: '%s'
        layout: cover
        highlighter: shiki
        lineNumbers: false
        drawings:
          persist: false
        download: true
        mdc: true
        talkDurationMinutes: #{@talk.duration_minutes}
        progressBarStartSlide: 2
        ---

        # #{@talk.title}

        #{@talk.description}

        <div class="absolute bottom-10 left-10">
          <small>Duration: #{@talk.duration_minutes} minutes | Audience: #{@talk.target_audience}</small>
        </div>

        <!--
        #{@talk.slides.first&.notes || "Welcome to the presentation!"}
        -->

      SLIDEV

      # Add each slide
      @talk.slides.each_with_index do |slide, index|
        next unless index.positive? # Skip first slide as it's already in the cover

        content += "---\n"

        # Add layout hints based on content
        content += "layout: two-cols\n" if slide.content.length > 5

        content += "\n# #{slide.title}\n\n"

        if slide.content.length > 5
          # Split content for two columns
          mid_point = (slide.content.length / 2.0).ceil
          content += "::left::\n\n"
          slide.content[0...mid_point].each { |point| content += "- #{point}\n" }
          content += "\n::right::\n\n"
          slide.content[mid_point..].each { |point| content += "- #{point}\n" }
        else
          slide.content.each { |point| content += "- #{point}\n" }
        end

        content += "\n<!--\n#{slide.notes}\n-->\n" unless slide.notes.strip.empty?

        content += "\n"
      end

      # Add a thank you slide
      content += <<~SLIDEV
        ---
        layout: center
        class: text-center
        ---

        # Thank You!

        Questions?

        <!--
        Thank you for your attention. I'm happy to answer any questions you may have.
        -->
      SLIDEV

      File.write(filename, content)
    end

    # Check if a slide is an IRB demo slide
    def is_irb_slide?(slide)
      return false unless slide

      # Check if slide title or content mentions IRB or has code examples
      slide.title.downcase.include?("irb") ||
        slide.content.any? { |line| line.include?("```ruby") || line.downcase.include?("irb") }
    end

    # Execute Ruby code from a demo slide
    def launch_irb_for_slide(slide)
      system("clear") || system("cls")

      puts "╔#{"═" * 78}╗".cyan
      puts "║#{slide.title.center(78).cyan.bold}║".cyan
      puts "╚#{"═" * 78}╝".cyan
      puts

      # Extract Ruby code from slide content
      ruby_code = extract_ruby_code(slide.content)

      if ruby_code.any?
        puts "💎 Executing Ruby code...".green.bold
        puts "─" * 40

        # Create a binding for our execution context
        demo_binding = binding
        demo_binding.eval("require 'stringio'")

        ruby_code.each do |code|
          puts "#{"> ".green.bold}#{code.yellow}"

          # Capture stdout
          old_stdout = $stdout
          captured_output = StringIO.new

          begin
            # Redirect stdout to capture output
            $stdout = captured_output

            # Show warnings for chilled strings
            old_verbose = $VERBOSE
            $VERBOSE = true
            Warning[:deprecated] = true if defined?(Warning)

            # Capture warnings
            old_stderr = $stderr
            captured_warnings = StringIO.new
            $stderr = captured_warnings

            # Evaluate the code
            result = demo_binding.eval(code)

            # Restore stderr and stdout
            $stderr = old_stderr
            $stdout = old_stdout
            $VERBOSE = old_verbose

            # Display any warnings first (in yellow)
            warnings = captured_warnings.string
            if warnings && !warnings.empty?
              warnings.each_line do |warning|
                puts "⚠️  #{warning.strip}".yellow if warning.strip.length.positive?
              end
            end

            # Display captured output
            output = captured_output.string
            unless output.empty?
              # Format benchmark output specially
              if output.include?("user") && output.include?("system") && output.include?("total")
                # It's benchmark output - format it nicely
                output.each_line do |line|
                  if line.include?("user") && line.include?("system")
                    # Header line
                    puts line.cyan
                  elsif line.match(/^\s*(mutable:|frozen:)/)
                    # Benchmark result lines - highlight the times
                    parts = line.split(/\s+/)
                    label = parts[0]
                    times = parts[1..]

                    # Format with colors
                    print "  #{label.ljust(12).yellow}"
                    times.each_with_index do |time, idx|
                      if idx == 2 # total time column
                        print time.rjust(12).green.bold
                      else
                        print time.rjust(12).light_black
                      end
                    end
                    puts
                  else
                    print line
                  end
                end
              else
                print output
              end
            end

            # Display the result
            if result.nil?
              puts "=> nil".light_black
            elsif result.is_a?(Benchmark::Tms) || result.to_s.include?("Benchmark")
              # Don't show benchmark objects as results
            else
              puts "=> #{result.inspect}".green
            end
          rescue StandardError => e
            $stdout = old_stdout
            $stderr = old_stderr if defined?(old_stderr)
            puts "❌ #{e.class}: #{e.message}".red
          end
        end

        puts "─" * 40
      else
        puts "No Ruby code found in this slide.".yellow
      end

      puts "\n🎬 Press any key to return to slideshow...".white
      get_single_keypress
    end

    # Extract Ruby code examples from slide content
    def extract_ruby_code(content)
      ruby_code = []
      in_code_block = false

      content.each do |line|
        if line.strip == "```ruby"
          in_code_block = true
          next
        elsif line.strip == "```"
          in_code_block = false
          next
        elsif in_code_block
          # Skip comments and empty lines, extract actual Ruby commands
          clean_line = line.strip
          next if clean_line.empty? || clean_line.start_with?("#")

          ruby_code << clean_line
        end
      end

      ruby_code
    end
  end
end
