# frozen_string_literal: true

require "tty-prompt"
require "tty-spinner"
require "colorize"
require_relative "ollama_client"
require_relative "web_content_fetcher"
require_relative "serper_client"

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
      @auto_save_enabled = true
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
      if @talk && @auto_save_enabled
        puts "\n\n💾 Saving your work before exit...".blue
        auto_save
        puts "\n✅ Work saved successfully!".green
      elsif @talk && !@auto_save_enabled
        puts "\n\n⚠️  You have unsaved changes!".yellow
        if @current_filename
          puts "Last saved to: #{@current_filename}".light_blue
        else
          puts "This talk has never been saved.".light_blue
        end
      end
      puts "Goodbye! 👋".green
      exit(0)
    end

    def setup_ai
      # First, try Ollama (local AI)
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

      puts "ℹ️  AI features disabled. To enable:".light_blue
      puts "   - Make sure Ollama is running: ollama serve".light_blue
      puts "   - Or configure RubyLLM with API keys".light_blue
    end

    def ai_ask(prompt, system: nil)
      return nil unless @ai_available

      case @ai_client
      when OllamaClient
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
        puts "ℹ️  Fact-checking features disabled. Serper API key not found.".light_blue
        puts "   You can enable fact-checking by setting SERPER_KEY environment variable".light_blue
        puts "   Get a free key at: https://serper.dev".light_blue

        # Only ask interactively if not in a test environment
        if !(ENV["RAKE_TEST"] || $0.include?("rake") || ENV.fetch("CI",
                                                                  nil)) && @prompt.yes?("Would you like to set up fact-checking with Google search? (requires Serper API key)")
          setup_serper_key
        end
      end
    end

    def setup_serper_key
      puts "\n🔑 Serper API Setup".cyan.bold
      puts "Serper provides Google search API for fact-checking your slides.".light_blue
      puts "Get a free API key at: https://serper.dev".light_blue

      api_key = @prompt.mask("Enter your Serper API key:")

      if api_key && !api_key.empty?
        ENV["SERPER_KEY"] = api_key
        @serper_client = SerperClient.new

        if @serper_client.available?
          puts "✅ Serper API key configured successfully!".green
          puts "Fact-checking features are now available.".light_blue
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
      return unless @auto_save_enabled && @talk

      # Generate filename if we don't have one
      if @current_filename.nil?
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        safe_title = @talk.title.downcase.gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_").chomp("_")
        safe_title = "untitled" if safe_title.empty?
        @current_filename = "#{safe_title}_#{timestamp}.json"
        puts "💾 Auto-saving as: #{@current_filename}".light_blue
      end

      begin
        @talk.save_to_file(@current_filename)
        print "💾" # Simple save indicator
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
        { name: "Create complete talk with AI" + (@ai_available ? "" : " (unavailable)"), value: :ai_complete,
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
      puts @talk.summary.light_blue

      # Auto-save after creating talk
      auto_save

      return unless @ai_available && @prompt.yes?("\nWould you like AI help creating your first slide?")

      create_ai_slide
    end

    def create_complete_talk_with_ai
      puts "\n🤖 Let's create a complete talk with AI assistance!".green
      puts "I'll guide you through the process step by step.\n".light_blue

      # Get the title
      title = @prompt.ask("What's the title of your talk?") do |q|
        q.required(true)
        q.modify(:strip)
      end

      # Get initial description - more detailed for AI
      puts "\n📝 Now let's describe your talk in detail...".yellow
      puts "This description helps the AI understand your goals and create better content.".light_blue

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
        questions = response.strip.split("\n").select { |line| line.match?(/^\d+\./) }

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

          json_response[start_index..-1].each_char.with_index(start_index) do |char, i|
            bracket_count += 1 if char == "{"
            bracket_count -= 1 if char == "}"
            if bracket_count == 0
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
        puts "\n📋 Here's the proposed talk structure:".blue
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
            puts "Total slides: #{@talk.slides.length}".blue

            # Auto-save after creating complete talk
            auto_save

            puts "\nYou can now edit individual slides, reorder them, or export your talk.".light_blue
          else
            puts "\nNo problem! The talk has been created without slides.".yellow
            puts "You can add slides manually or use AI assistance from the main menu.".light_blue
          end
        else
          puts "\nAI couldn't generate slides automatically, but the talk structure is ready.".yellow
          puts "You can add slides manually or use AI assistance from the main menu.".light_blue
        end
      rescue JSON::ParserError
        puts "\n❌ AI response wasn't in expected JSON format. Using simpler approach.".red
        puts "✅ Basic talk structure created successfully!".green
        auto_save  # Save what we have
        puts @talk.summary.light_blue
        puts "\n💡 You can now add slides manually or use individual AI assistance from the main menu.".blue
      rescue StandardError => e
        puts "\n❌ Error with AI generation: #{e.message}".red
        puts "✅ Basic talk structure created successfully!".green
        auto_save  # Save what we have
        puts @talk.summary.light_blue
        puts "\n💡 You can now add slides manually or use individual AI assistance from the main menu.".blue
      end
    end

    def load_talk
      # Find all JSON files in the current directory
      json_files = Dir.glob("*.json").sort_by { |f| File.mtime(f) }.reverse

      if json_files.empty?
        puts "\n📁 No talk files found in current directory.".yellow
        puts "   Create a new talk or make sure you're in the right directory.".light_blue
        return
      end

      puts "\n📁 Available talk files (most recent first):".blue

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
          puts "\n✅ Talk loaded successfully!".green
          puts @talk.summary.light_blue
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

      puts "\n📁 JSON files in #{File.expand_path(path)} (most recent first):".blue

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
      puts "\n📚 Sample Talks:".blue

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
      puts "\n#{sample_talk[:title].bold.blue}"
      puts sample_talk[:description]
      puts "\nSlides:".bold

      sample_talk[:slides].each_with_index do |slide, index|
        puts "\n#{index + 1}. #{slide[:title].bold}"
        slide[:content].each { |point| puts "   • #{point}" }
      end

      @prompt.keypress("\nPress any key to continue...")
    end

    def main_menu
      auto_save_status = @auto_save_enabled ? "ON" : "OFF"
      current_file_info = @current_filename ? " [#{@current_filename}]" : " [unsaved]"

      choice = @prompt.select("\n🎤 #{@talk.title}#{current_file_info}".bold + " - What would you like to do?", [
                                { name: "View talk overview", value: :overview },
                                { name: "Create new slide", value: :new_slide },
                                { name: "Edit existing slide", value: :edit_slide },
                                { name: "Reorder slides", value: :reorder },
                                { name: "Delete slide", value: :delete_slide },
                                { name: "AI assistance", value: :ai_help },
                                { name: "Save talk", value: :save },
                                { name: "Export talk", value: :export },
                                { name: "Auto-save: #{auto_save_status} (toggle)", value: :toggle_autosave },
                                { name: "Start over (new talk)", value: :new_talk },
                                { name: "Exit", value: :exit },
                              ])

      case choice
      when :overview
        show_talk_overview
      when :new_slide
        create_new_slide
      when :edit_slide
        edit_slide_menu
      when :reorder
        reorder_slides
      when :delete_slide
        delete_slide
      when :ai_help
        ai_assistance_menu
      when :save
        save_talk
      when :export
        export_talk
      when :toggle_autosave
        toggle_autosave
      when :new_talk
        @talk = nil
        @current_filename = nil # Reset filename for new talk
      when :exit
        puts "Goodbye! 👋".green
        exit(0)
      end
    end

    def toggle_autosave
      @auto_save_enabled = !@auto_save_enabled
      status = @auto_save_enabled ? "enabled" : "disabled"
      puts "\n💾 Auto-save has been #{status}".blue

      if @auto_save_enabled
        puts "   Your work will be automatically saved after each change.".light_blue
        if @current_filename
          puts "   Saving to: #{@current_filename}".light_blue
        else
          puts "   A filename will be generated automatically when needed.".light_blue
        end
      else
        puts "   Remember to save manually to avoid losing your work!".yellow
      end
    end

    def show_talk_overview
      puts "\n" + @talk.summary.light_blue

      if @talk.slides.any? && @prompt.yes?("\nWould you like to see detailed slide content?")
        @talk.slides.each_with_index do |slide, index|
          puts "\n" + ("─" * 50)
          puts "Slide #{index + 1}:".bold
          puts slide
        end
      end

      @prompt.keypress("\nPress any key to continue...")
    end

    def create_new_slide
      puts "\n📄 Creating new slide...".green

      slide = @talk.add_slide
      edit_slide(slide)
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

        puts "\n🎯 AI Suggestions:".blue
        puts response.light_blue

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
        puts "\n" + ("─" * 50)
        puts "Editing Slide #{slide.number}:".bold
        puts slide

        if ai_suggestions
          puts "\n🤖 AI Suggestions:".blue
          puts ai_suggestions.light_blue
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

        puts "\n🎯 AI Improvement Suggestions:".blue
        puts response.light_blue

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
      puts "AI will analyze your presentation structure and offer to fix issues automatically.".light_blue

      return puts "No slides to review yet.".yellow if @talk.slides.empty?

      # Get user input on what to focus on
      puts "\n📋 What would you like the AI to focus on?".yellow
      puts "Select at least one area (use SPACE to select, ENTER to confirm):".light_blue

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
          puts "Analysis cancelled.".light_blue
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
      puts "   Looking for fixes and improvements...".light_blue

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
        puts "\n🔍 Structure Analysis:".blue.bold
        puts text_analysis.light_blue

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

        puts "   Parsing fix response...".light_blue
        issues_and_fixes = parse_structure_analysis(json_response)

        if issues_and_fixes && issues_and_fixes["fixes"]&.any?
          puts "\n🔄 Auto-Fix Mode Activated".cyan.bold
          puts "I'll automatically apply fixes and re-analyze for continuous improvement.".light_blue

          # Iterative improvement loop
          iteration = 1
          max_iterations = 3
          total_fixes_applied = 0

          loop do
            puts "\n📍 Iteration #{iteration}/#{max_iterations}".yellow

            fixes_to_apply = issues_and_fixes["fixes"].select { |fix| can_auto_apply?(fix) }

            if fixes_to_apply.empty?
              puts "No more auto-applicable fixes found.".light_blue
              break
            end

            puts "Found #{fixes_to_apply.length} fixes to apply...".light_blue
            fixes_applied = apply_structure_fixes_auto(fixes_to_apply)
            total_fixes_applied += fixes_applied

            break if iteration >= max_iterations

            unless fixes_applied > 0 && @prompt.yes?("\n🔄 #{fixes_applied} fixes applied. Continue improving? (Iteration #{iteration + 1}/#{max_iterations})")
              break
            end

            iteration += 1
            puts "\n🔍 Re-analyzing structure after fixes...".yellow

            # Re-run the JSON fixes prompt with updated presentation
            json_response = ai_ask_with_spinner(fixes_prompt, message: "Re-analyzing presentation structure...")
            new_issues_and_fixes = parse_structure_analysis(json_response)

            if new_issues_and_fixes && new_issues_and_fixes["fixes"]&.any?
              puts "\n📊 New Analysis Results:".blue
              puts "Found #{new_issues_and_fixes["fixes"].length} additional improvements".light_blue
              issues_and_fixes = new_issues_and_fixes
            else
              puts "\n✅ No more improvements needed!".green
              break
            end
          end

          puts "\n🎉 Auto-Fix Complete!".green.bold
          puts "Total fixes applied: #{total_fixes_applied}".blue
          puts "Iterations completed: #{iteration}".blue

          # Show final structure overview
          if total_fixes_applied > 0 && @prompt.yes?("\nWould you like to see the improved structure?")
            show_talk_overview
          end
        else
          puts "\n⚠️  No applicable fixes found in the response.".yellow
          puts "The analysis was helpful, but no automatic fixes could be generated.".light_blue
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
      puts "\n📊 Structure Analysis Results:".blue.bold

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
          puts "   Category: #{issue["category"].capitalize}".light_blue
          puts "   Severity: #{issue["severity"].upcase}".send(severity_color)
          puts "   Affects slides: #{issue["affected_slides"]&.join(", ") || "Multiple"}".light_blue
          puts "   Impact: #{issue["impact"]}".light_blue if issue["impact"]
        end
      end

      if analysis["fixes"]&.any?
        puts "\n🛠️  Suggested Fixes:".green.bold
        analysis["fixes"].each_with_index do |fix, i|
          puts "\n#{i + 1}. #{fix["description"]}".green
          puts "   Type: #{fix["type"].gsub("_", " ").capitalize}".light_blue
          puts "   Action: #{fix["action"]}".light_blue
          puts "   Position: #{fix["position"]}".light_blue if fix["position"]
        end
      end

      return unless analysis["overall_assessment"]

      puts "\n📋 Overall Assessment:".cyan.bold
      puts analysis["overall_assessment"].light_blue
    end

    def can_auto_apply?(fix)
      fix_type = parse_fix_type(fix["type"])
      %w[add_slide modify_slide].include?(fix_type)
    end

    def apply_structure_fixes_auto(fixes)
      fixes_applied = 0

      fixes.each_with_index do |fix, i|
        puts "\n#{i + 1}. #{fix["description"]}".blue

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

      if fixes_applied > 0
        # Renumber all slides
        @talk.slides.each_with_index { |s, i| s.number = i + 1 }
        auto_save
      end

      fixes_applied
    end

    def apply_structure_fixes(fixes)
      puts "\n🔧 Applying structure fixes...".yellow
      fixes_applied = 0

      fixes.each_with_index do |fix, i|
        puts "\n#{i + 1}. #{fix["description"]}".blue

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

      if fixes_applied > 0
        # Renumber all slides
        @talk.slides.each_with_index { |s, i| s.number = i + 1 }
        auto_save

        puts "\n🎉 Applied #{fixes_applied}/#{fixes.length} fixes successfully!".green.bold
        puts "Your presentation structure has been improved.".light_blue

        show_talk_overview if @prompt.yes?("\nWould you like to review the updated structure?")
      else
        puts "\n⚠️  No fixes could be applied automatically.".yellow
        puts "Please review the suggestions and make manual changes.".light_blue
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
      return unless slide_num && slide_num > 0 && slide_num <= @talk.slides.length

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
      puts "   Suggestion: #{fix["action"]}".light_blue
    end

    def apply_split_slide_fix(fix)
      # Complex operation - notify user to do manually
      puts "   ⚠️  Slide splitting requires manual action".yellow
      puts "   Suggestion: #{fix["action"]}".light_blue
    end

    def apply_merge_slides_fix(fix)
      # Complex operation - notify user to do manually
      puts "   ⚠️  Slide merging requires manual action".yellow
      puts "   Suggestion: #{fix["action"]}".light_blue
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
        puts "   💡 Manual steps: Use 'Reorder slides' from the main menu".light_blue
        puts "      Suggestion: #{fix["action"]}".light_blue
      when /split|divide/i
        puts "   💡 Manual steps: Edit the slide and break content into multiple slides".light_blue
        puts "      Suggestion: #{fix["action"]}".light_blue
      when /merge|combine/i
        puts "   💡 Manual steps: Copy content from multiple slides into one".light_blue
        puts "      Suggestion: #{fix["action"]}".light_blue
      when /interactive|engagement/i
        puts "   💡 Manual steps: Edit slides to add interactive elements".light_blue
        puts "      Ideas: Add Q&A prompts, polls, or exercises".light_blue
      when /example|case.?study/i
        puts "   💡 Manual steps: Add new slides with real-world examples".light_blue
        puts "      Use 'Create new slide' and add practical examples".light_blue
      else
        puts "   💡 Manual steps required:".light_blue
        puts "      #{fix["action"]}".light_blue

        # Try to suggest the best approach based on the description
        description = fix["description"].downcase
        if description.include?("add") || description.include?("create")
          puts "      → Consider using 'Create new slide' from the main menu".light_blue
        elsif description.include?("edit") || description.include?("modify") || description.include?("update")
          puts "      → Use 'Edit existing slide' from the main menu".light_blue
        elsif description.include?("remove") || description.include?("delete")
          puts "      → Use 'Delete slide' from the main menu".light_blue
        end
      end
    end

    def ai_presentation_tips
      puts "\n🤖 Getting presentation tips...".yellow

      begin
        tips_prompt = "Provide 5-7 practical tips for delivering an engaging presentation on '#{@talk.title}' to #{@talk.target_audience}. Focus on delivery, audience engagement, and handling Q&A."

        response = ai_ask_with_spinner(tips_prompt, message: "Generating presentation tips...")

        puts "\n🎯 Presentation Tips:".blue
        puts response.light_blue

        @prompt.keypress("\nPress any key to continue...")
      rescue StandardError => e
        puts "❌ AI assistance failed: #{e.message}".red
      end
    end

    def integrate_web_content
      puts "\n🌐 Integrate Web Content".cyan.bold
      puts "Fetch content from a website and incorporate it into your slides.".light_blue

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
      puts "📄 Content length: #{result[:content].length} characters".light_blue

      # Show preview of content
      preview = result[:content][0..500]
      preview += "..." if result[:content].length > 500

      puts "\n📋 Content Preview:".blue
      puts preview.light_blue

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
          @talk.slides.each_with_index { |s, i| s.number = i + 1 }
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

      puts "🔍 Finding slides that match the web content...".light_blue
      matching_response = ai_ask_with_spinner(analysis_prompt, message: "Analyzing slide relevance...")

      if matching_response.nil? || matching_response.strip.empty?
        puts "❌ Could not analyze slide relevance. Falling back to manual selection.".red
        return manual_slide_selection(web_content, source_url)
      end

      # Parse the matching analysis
      slide_matches = parse_slide_matching_response(matching_response)

      if slide_matches.empty?
        puts "\n📋 Analysis Results:".blue
        puts matching_response.light_blue
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
      puts "\n🎯 AI Found Relevant Slides:".blue.bold
      slide_matches.each_with_index do |match, i|
        slide = @talk.slides[match[:slide_index]]
        puts "\n#{i + 1}. #{slide.display_summary}".green
        puts "   Relevance: #{match[:relevance]}".light_blue
        puts "   Why: #{match[:reason]}".light_blue
        puts "   Suggested enhancement: #{match[:enhancement]}".cyan
      end

      unless @prompt.yes?("\n🚀 Apply these enhancements automatically?")
        return manual_slide_selection(web_content, source_url)
      end

      # Ask for general integration guidance
      integration_guidance = @prompt.multiline("Any specific guidance for how to integrate the content? (Press Enter twice when done, or leave blank for AI to decide)").join("\n")

      # Apply enhancements to the AI-selected slides
      slide_matches.each do |match|
        slide = @talk.slides[match[:slide_index]]

        puts "\n🔧 Enhancing: #{slide.title}".blue

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
          @talk.slides.each_with_index { |s, i| s.number = i + 1 }
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
      puts "This mode helps you add multiple slides to reach the appropriate length for your talk.".light_blue

      # Calculate recommended slide count
      recommended_slides = calculate_recommended_slides(@talk.duration_minutes)
      current_slides = @talk.slides.length

      puts "\n📊 Presentation Analysis:".yellow
      puts "   Duration: #{@talk.duration_minutes} minutes"
      puts "   Current slides: #{current_slides}"
      puts "   Recommended slides: #{recommended_slides} (at ~1-2 minutes per slide)"
      puts "   Suggested additions: #{[recommended_slides - current_slides, 0].max} more slides"

      if current_slides == 0
        puts "\n⚠️  No slides yet. Please create some slides first.".yellow
        puts "   Use 'Create complete talk with AI' from the main menu.".light_blue
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
      puts "\n📍 Add Slides at Specific Positions".blue

      # Show current structure
      puts "\nCurrent slide structure:".bold
      @talk.slides.each_with_index do |slide, i|
        puts "#{i + 1}. #{slide.title}"
      end

      # Ask where to insert
      position = @prompt.ask("\nInsert after which slide? (0 for beginning):", convert: :int)

      if position < 0 || position > @talk.slides.length
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
        before_slide = position > 0 ? @talk.slides[position - 1] : nil
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
          @talk.slides.each_with_index { |s, i| s.number = i + 1 }

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
      puts "\n📈 Expand Specific Sections".blue

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
          @talk.slides.each_with_index { |s, i| s.number = i + 1 }

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
      puts "\n🔗 Fill Gaps Between Slides".blue

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

      puts "\n🚀 Generating Complete Slide Set".blue
      puts "Current: #{current_count} slides → Target: #{target_count} slides".light_blue

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
            if added_count % 5 == 0
              puts "   Progress: #{added_count}/#{target_count - current_count} slides added...".light_blue
            end
          end

          # Renumber all slides
          @talk.slides.each_with_index { |s, i| s.number = i + 1 }

          auto_save

          puts "\n🎉 Presentation expanded to #{@talk.slides.length} slides!".green.bold
          puts "   Ready for a #{@talk.duration_minutes}-minute presentation".blue

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
      puts "AI will verify claims in your slides using Google search and web sources.".light_blue

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
        puts "\n📍 Checking slide #{slide_index + 1}/#{@talk.slides.length}: #{slide.title}".blue

        # Step 1: Extract claims from the slide
        claims = extract_claims_from_slide(slide)

        if claims.empty?
          puts "   ⚠️  No verifiable claims found in this slide".yellow
          next
        end

        puts "   Found #{claims.length} claims to verify...".light_blue

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
      puts "   🔍 Extracting verifiable claims...".light_blue

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
      puts "   🌐 Searching Google for verification...".light_blue

      search_results = []

      claims.each_with_index do |claim, i|
        puts "     Claim #{i + 1}: #{claim[0..50]}...".light_blue

        result = @serper_client.search_for_fact_checking([claim])
        search_results.concat(result) if result.any?

        # Rate limiting
        sleep(0.5) if i < claims.length - 1
      end

      search_results
    end

    def fetch_web_evidence(search_results)
      puts "   📄 Fetching web evidence...".light_blue

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
      puts "   🤖 AI analyzing evidence...".light_blue

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
        "Source: #{evidence[:source_title]} (#{evidence[:source_url]})\n" +
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
      if match = analysis_text.match(/OVERALL_VERDICT:\s*(.+?)$/m)
        result[:overall_verdict] = match[1].strip
      end

      # Extract claim analyses
      claim_sections = analysis_text.split(/CLAIM_ANALYSIS:|Claim \d+:/).drop(1)
      claim_sections.each do |section|
        claim_verdict = {}

        if match = section.match(/Verdict:\s*(.+?)$/m)
          claim_verdict[:verdict] = match[1].strip
        end

        if match = section.match(/Confidence:\s*(.+?)$/m)
          claim_verdict[:confidence] = match[1].strip
        end

        if match = section.match(/Evidence:\s*(.+?)(?=Sources:|RECOMMENDATIONS:|$)/m)
          claim_verdict[:evidence] = match[1].strip
        end

        if match = section.match(/Sources:\s*(.+?)(?=RECOMMENDATIONS:|$)/m)
          claim_verdict[:sources] = match[1].strip
        end

        result[:claim_verdicts] << claim_verdict if claim_verdict.any?
      end

      # Extract recommendations
      if match = analysis_text.match(/RECOMMENDATIONS:\s*(.+?)(?=SUMMARY:|$)/m)
        recommendations_text = match[1].strip
        result[:recommendations] = recommendations_text.split(/\n-\s*/).map(&:strip).reject(&:empty?)
      end

      # Extract summary
      if match = analysis_text.match(/SUMMARY:\s*(.+?)$/m)
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
      puts "\n   📊 Fact-Check Results for: #{slide.title}".blue.bold

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
        puts "\n   💡 Recommendations:".cyan
        result[:recommendations].each do |rec|
          puts "   • #{rec}"
        end
      end

      # Display checked URLs for transparency
      if checked_urls.any?
        puts "\n   🔗 Sources Checked:".light_blue
        checked_urls.first(5).each do |url_info|
          puts "   • #{url_info[:title]}"
          puts "     #{url_info[:url]}".light_black
        end
        puts "   ... and #{checked_urls.length - 5} more sources".light_black if checked_urls.length > 5
      end

      puts "\n   📝 Summary: #{result[:summary]}".light_blue if result[:summary]
    end

    def display_fact_check_summary(results)
      return if results.empty?

      puts "\n" + ("=" * 60)
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

      if contradicted_count > 0 || partial_count > 0
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
        puts "\n📍 Reviewing: #{slide.title}".blue

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
      puts "\n📚 Adding citation suggestions to speaker notes...".blue

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
      puts "\n🤖 AI improving slide based on fact-check results...".blue

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
      puts "   #{improvement_data["improved_notes"][0..200]}...".light_blue

      if improvement_data["changes_made"]&.any?
        puts "\n🔄 Changes Made:".yellow
        improvement_data["changes_made"].each do |change|
          puts "   • #{change}"
        end
      end

      puts "\n🎯 AI Confidence: #{improvement_data["confidence"]}".cyan

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
          puts "\n🔄 Re-checking improved slide...".blue

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
        puts "   Attempting AI-assisted JSON correction...".light_blue

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
        puts "   Trying simple automatic fixes...".light_blue
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

      response[start_index..-1].each_char.with_index(start_index) do |char, i|
        bracket_count += 1 if char == "{"
        bracket_count -= 1 if char == "}"
        if bracket_count == 0
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

    def save_talk
      filename = @prompt.ask("Enter filename (without extension):",
                             default: @talk.title.downcase.gsub(/[^a-z0-9]/, "_"))
      full_filename = "#{filename}.json"

      @talk.save_to_file(full_filename)
      @current_filename = full_filename # Update current filename for future auto-saves
      puts "✅ Talk saved as #{full_filename}".green
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
      content += ("=" * @talk.title.length) + "\n\n"
      content += "Description: #{@talk.description}\n"
      content += "Target Audience: #{@talk.target_audience}\n"
      content += "Duration: #{@talk.duration_minutes} minutes\n\n"

      @talk.slides.each_with_index do |slide, index|
        content += "#{index + 1}. #{slide.title}\n"
        content += ("-" * (slide.title.length + 3)) + "\n"
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
        next unless index > 0 # Skip first slide as it's already in the cover

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
          slide.content[mid_point..-1].each { |point| content += "- #{point}\n" }
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
  end
end
