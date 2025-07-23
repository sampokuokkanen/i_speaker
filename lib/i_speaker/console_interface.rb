# frozen_string_literal: true

require "tty-prompt"
require "colorize"
require_relative "ollama_client"

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
      @current_filename = nil
      @auto_save_enabled = true
      setup_ai
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
        rescue => e
          puts "⚠️  RubyLLM error: #{e.message}".yellow
        end
      end

      unless @ai_available
        puts "ℹ️  AI features disabled. To enable:".light_blue
        puts "   - Make sure Ollama is running: ollama serve".light_blue
        puts "   - Or configure RubyLLM with API keys".light_blue
      end
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
        print "💾"  # Simple save indicator
      rescue => e
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
        { name: "Create complete talk with AI" + (@ai_available ? "" : " (unavailable)"), value: :ai_complete, disabled: !@ai_available },
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

      if @ai_available && @prompt.yes?("\nWould you like AI help creating your first slide?")
        create_ai_slide
      end
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
      unless topic_context.strip.empty?
        full_context += "\n\nAdditional context: #{topic_context}"
      end

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
          #{topic_context.strip.empty? ? "" : "Additional context: #{topic_context}"}
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

        response = ai_ask(questions_prompt)
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
          #{topic_context.strip.empty? ? "" : "Additional context: #{topic_context}"}
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

        json_response = ai_ask(structure_prompt)
        
        # Parse JSON response more robustly
        require 'json'
        
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
            puts "\n#{index + 1}. #{slide_data['title'] || "Slide #{index + 1}"}"
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

      rescue JSON::ParserError => e
        puts "\n❌ AI response wasn't in expected JSON format. Using simpler approach.".red
        puts "✅ Basic talk structure created successfully!".green
        auto_save  # Save what we have
        puts @talk.summary.light_blue
        puts "\n💡 You can now add slides manually or use individual AI assistance from the main menu.".blue
      rescue => e
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
      json_files.each_with_index do |filename, index|
        begin
          # Try to get basic info about the talk
          data = JSON.parse(File.read(filename), symbolize_names: true)
          title = data[:title] || "Untitled"
          slide_count = data[:slides]&.length || 0
          duration = data[:duration_minutes] || "Unknown"
          modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")
          
          display_name = "#{filename} - \"#{title}\" (#{slide_count} slides, #{duration}min) [#{modified_time}]"
          file_options << { name: display_name, value: filename }
        rescue
          # If we can't parse the file, still show it but with warning
          modified_time = File.mtime(filename).strftime("%Y-%m-%d %H:%M")
          display_name = "#{filename} - ⚠️  Invalid JSON format [#{modified_time}]"
          file_options << { name: display_name, value: filename }
        end
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
        return
      else
        load_talk_file(choice)
      end
    end

    def load_talk_file(filename)
      if File.exist?(filename)
        begin
          @talk = Talk.load_from_file(filename)
          @current_filename = filename  # Set current filename for auto-save
          puts "\n✅ Talk loaded successfully!".green
          puts @talk.summary.light_blue
        rescue => e
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
        rescue
          # If we can't parse the file, still show it but with warning
          modified_time = File.mtime(full_path).strftime("%Y-%m-%d %H:%M")
          display_name = "#{filename} - ⚠️  Invalid JSON format [#{modified_time}]"
          file_options << { name: display_name, value: full_path }
        end
      end

      file_options << { name: "🔙 Back to load menu", value: :back }

      choice = @prompt.select("Select a file to load:", file_options)

      if choice != :back
        load_talk_file(choice)
      end
    end

    def view_sample_talks
      puts "\n📚 Sample Talks:".blue

      SampleTalks.all.each_with_index do |talk, index|
        puts "\n#{index + 1}. #{talk[:title].bold}"
        puts "   #{talk[:description]}"
        puts "   Slides: #{talk[:slides].length}"
      end

      if @prompt.yes?("\nWould you like to see details of a specific sample?")
        choice = @prompt.select(
          "Which sample would you like to explore?",
          SampleTalks.all.map.with_index { |talk, i| { name: talk[:title], value: i } },
        )

        show_sample_talk_details(SampleTalks.all[choice])
      end
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
        @current_filename = nil  # Reset filename for new talk
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

      if @talk.slides.any?
        if @prompt.yes?("\nWould you like to see detailed slide content?")
          @talk.slides.each_with_index do |slide, index|
            puts "\n" + "─" * 50
            puts "Slide #{index + 1}:".bold
            puts slide
          end
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

        response = ai_ask(ai_prompt)

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
      rescue => e
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
        puts "\n" + "─" * 50
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
          auto_save  # Auto-save after editing slide
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

        response = ai_ask(ai_prompt)

        puts "\n🎯 AI Improvement Suggestions:".blue
        puts response.light_blue

        @prompt.keypress("\nPress any key to continue editing...")
      rescue => e
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
        auto_save  # Auto-save after reordering slides
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

      if @prompt.yes?("Are you sure you want to delete '#{slide.title}'?")
        @talk.remove_slide(slide_index)
        puts "✅ Slide deleted successfully!".green
        auto_save  # Auto-save after deleting slide
      end
    end

    def ai_assistance_menu
      return puts "AI assistance is not available.".red unless @ai_available

      loop do
        choice = @prompt.select("How can AI help you?", [
          { name: "Create next slide", value: :next_slide },
          { name: "AI Fix Mode - Add/Insert multiple slides", value: :ai_fix_mode },
          { name: "Improve existing slide", value: :improve_slide },
          { name: "Review and Fix Structure", value: :review_and_fix_structure },
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
      
      focus_areas = @prompt.multi_select("Select areas to review and fix:", [
        { name: "Flow and transitions between slides", value: :flow },
        { name: "Missing introduction/conclusion structure", value: :intro_conclusion },
        { name: "Slide count vs duration (pacing)", value: :pacing },
        { name: "Missing examples or case studies", value: :examples },
        { name: "Lack of interactive elements", value: :interactive },
        { name: "Content depth and balance", value: :depth },
        { name: "Audience engagement opportunities", value: :engagement },
        { name: "Technical accuracy and completeness", value: :technical },
        { name: "Repetition or redundant content", value: :redundancy },
        { name: "Overall presentation coherence", value: :coherence }
      ])
      
      return if focus_areas.empty?
      
      # Get specific issues user has noticed
      specific_issues = @prompt.multiline("Any specific issues you've noticed? (Press Enter twice when done, or leave blank)").join("\n")
      
      # Get target outcome
      target_outcome = @prompt.ask("What's your main goal for this presentation?", 
        default: "Engage audience and clearly communicate key concepts")
      
      puts "\n🤖 Analyzing presentation structure...".yellow
      puts "   Focus areas: #{focus_areas.map(&:to_s).join(', ')}"
      puts "   Looking for fixes and improvements...".light_blue
      
      begin
        # Create comprehensive review prompt
        review_prompt = build_structure_review_prompt(focus_areas, specific_issues, target_outcome)
        
        response = ai_ask(review_prompt)
        issues_and_fixes = parse_structure_analysis(response)
        
        if issues_and_fixes
          display_structure_analysis(issues_and_fixes)
          
          if issues_and_fixes["fixes"]&.any? && @prompt.yes?("\n🛠️  Would you like me to apply the suggested fixes?")
            apply_structure_fixes(issues_and_fixes["fixes"])
          end
        else
          puts "\n🎯 Structure Analysis:".blue
          puts response.light_blue
          @prompt.keypress("\nPress any key to continue...")
        end
        
      rescue => e
        puts "❌ Analysis failed: #{e.message}".red
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
        #{@talk.slides.map.with_index(1) { |slide, i| "#{i}. #{slide.title}\n   Content: #{slide.content.join(', ')}" }.join("\n\n")}

        #{specific_issues.empty? ? "" : "\n**Specific Issues to Address:**\n#{specific_issues}"}

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
              "type": "add_slide|modify_slide|reorder_slides|split_slide|merge_slides",
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

        Focus on providing 3-5 high-impact fixes that address the most critical issues.
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
          
          puts "\n#{i + 1}. #{issue['description']}".send(severity_color)
          puts "   Category: #{issue['category'].capitalize}".light_blue
          puts "   Severity: #{issue['severity'].upcase}".send(severity_color)
          puts "   Affects slides: #{issue['affected_slides']&.join(', ') || 'Multiple'}".light_blue
          puts "   Impact: #{issue['impact']}".light_blue if issue['impact']
        end
      end
      
      if analysis["fixes"]&.any?
        puts "\n🛠️  Suggested Fixes:".green.bold
        analysis["fixes"].each_with_index do |fix, i|
          puts "\n#{i + 1}. #{fix['description']}".green
          puts "   Type: #{fix['type'].gsub('_', ' ').capitalize}".light_blue
          puts "   Action: #{fix['action']}".light_blue
          puts "   Position: #{fix['position']}".light_blue if fix['position']
        end
      end
      
      if analysis["overall_assessment"]
        puts "\n📋 Overall Assessment:".cyan.bold
        puts analysis["overall_assessment"].light_blue
      end
    end

    def apply_structure_fixes(fixes)
      puts "\n🔧 Applying structure fixes...".yellow
      fixes_applied = 0
      
      fixes.each_with_index do |fix, i|
        puts "\n#{i + 1}. #{fix['description']}".blue
        
        begin
          case fix['type']
          when 'add_slide'
            apply_add_slide_fix(fix)
          when 'modify_slide'
            apply_modify_slide_fix(fix)
          when 'reorder_slides'
            apply_reorder_fix(fix)
          when 'split_slide'
            apply_split_slide_fix(fix)
          when 'merge_slides'
            apply_merge_slides_fix(fix)
          else
            puts "   ⚠️  Unknown fix type: #{fix['type']}".yellow
            next
          end
          
          fixes_applied += 1
          puts "   ✅ Applied successfully".green
          
        rescue => e
          puts "   ❌ Failed to apply: #{e.message}".red
        end
      end
      
      if fixes_applied > 0
        # Renumber all slides
        @talk.slides.each_with_index { |s, i| s.number = i + 1 }
        auto_save
        
        puts "\n🎉 Applied #{fixes_applied}/#{fixes.length} fixes successfully!".green.bold
        puts "Your presentation structure has been improved.".light_blue
        
        if @prompt.yes?("\nWould you like to review the updated structure?")
          show_talk_overview
        end
      else
        puts "\n⚠️  No fixes could be applied automatically.".yellow
        puts "Please review the suggestions and make manual changes.".light_blue
      end
    end

    def apply_add_slide_fix(fix)
      return unless fix['new_content']
      
      slide = Slide.new(
        title: fix['new_content']['title'] || "New Slide",
        content: fix['new_content']['content'] || ["Content point"],
        notes: fix['new_content']['notes'] || ""
      )
      
      # Determine insertion position
      if fix['position'] == 'end'
        @talk.slides << slide
      elsif fix['position']&.start_with?('after_slide_')
        position = fix['position'].sub('after_slide_', '').to_i
        position = [position, @talk.slides.length].min
        @talk.slides.insert(position, slide)
      else
        @talk.slides << slide
      end
      
      puts "   Added slide: #{slide.title}".green
    end

    def apply_modify_slide_fix(fix)
      # Extract slide number from position or action
      slide_num = extract_slide_number(fix['position'] || fix['action'])
      return unless slide_num && slide_num > 0 && slide_num <= @talk.slides.length
      
      slide = @talk.slides[slide_num - 1]
      
      if fix['new_content']
        slide.title = fix['new_content']['title'] if fix['new_content']['title']
        slide.content = fix['new_content']['content'] if fix['new_content']['content']
        slide.notes = fix['new_content']['notes'] if fix['new_content']['notes']
      end
      
      puts "   Modified slide #{slide_num}: #{slide.title}".green
    end

    def apply_reorder_fix(fix)
      # This would require more complex parsing of the fix action
      # For now, just notify that manual reordering is needed
      puts "   ⚠️  Slide reordering requires manual action".yellow
      puts "   Suggestion: #{fix['action']}".light_blue
    end

    def apply_split_slide_fix(fix)
      # Complex operation - notify user to do manually
      puts "   ⚠️  Slide splitting requires manual action".yellow
      puts "   Suggestion: #{fix['action']}".light_blue
    end

    def apply_merge_slides_fix(fix)
      # Complex operation - notify user to do manually  
      puts "   ⚠️  Slide merging requires manual action".yellow
      puts "   Suggestion: #{fix['action']}".light_blue
    end

    def extract_slide_number(text)
      return nil unless text
      match = text.match(/slide[_\s]?(\d+)/i)
      match ? match[1].to_i : nil
    end

    def ai_presentation_tips
      puts "\n🤖 Getting presentation tips...".yellow

      begin
        tips_prompt = "Provide 5-7 practical tips for delivering an engaging presentation on '#{@talk.title}' to #{@talk.target_audience}. Focus on delivery, audience engagement, and handling Q&A."

        response = ai_ask(tips_prompt)

        puts "\n🎯 Presentation Tips:".blue
        puts response.light_blue

        @prompt.keypress("\nPress any key to continue...")
      rescue => e
        puts "❌ AI assistance failed: #{e.message}".red
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
        { name: "Generate complete slide set (#{recommended_slides} slides)", value: :complete_set },
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
        return
      end
    end

    def calculate_recommended_slides(duration_minutes)
      # General guideline: 1-2 minutes per slide for most presentations
      # For technical talks, might be closer to 1 minute per slide
      # For story-driven talks, might be 2-3 minutes per slide
      
      case duration_minutes
      when 0..10
        duration_minutes  # ~1 slide per minute for short talks
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
        
        response = ai_ask(slides_prompt)
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
        
      rescue => e
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
          #{section_slides.map { |s| "- #{s.title}: #{s.content.join(', ')}" }.join("\n")}
          
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
        
        response = ai_ask(expansion_prompt)
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
        
      rescue => e
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
          
          response = ai_ask(bridge_prompt)
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
          
        rescue => e
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
      
      if !@prompt.yes?("\nThis will add #{target_count - current_count} slides. Continue?")
        return
      end
      
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
        
        response = ai_ask(complete_prompt)
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
          
          if @prompt.yes?("\nWould you like to review the new structure?")
            show_talk_overview
          end
        else
          puts "❌ Failed to generate complete slide set".red
        end
        
      rescue => e
        puts "❌ Error: #{e.message}".red
      end
    end

    def parse_ai_json_response(response)
      return nil unless response
      
      # Try to extract JSON from the response
      json_content = nil
      if response.include?("{") && response.include?("}")
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
        
        json_content = response[start_index..end_index]
      end
      
      JSON.parse(json_content || "{}")
    rescue JSON::ParserError => e
      puts "⚠️  JSON parsing error: #{e.message}".yellow
      nil
    end

    def save_talk
      filename = @prompt.ask("Enter filename (without extension):", default: @talk.title.downcase.gsub(/[^a-z0-9]/, "_"))
      full_filename = "#{filename}.json"

      @talk.save_to_file(full_filename)
      @current_filename = full_filename  # Update current filename for future auto-saves
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
      filename = @prompt.ask("Enter filename (without extension):", default: @talk.title.downcase.gsub(/[^a-z0-9]/, "_"))

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
      content += "=" * @talk.title.length + "\n\n"
      content += "Description: #{@talk.description}\n"
      content += "Target Audience: #{@talk.target_audience}\n"
      content += "Duration: #{@talk.duration_minutes} minutes\n\n"

      @talk.slides.each_with_index do |slide, index|
        content += "#{index + 1}. #{slide.title}\n"
        content += "-" * (slide.title.length + 3) + "\n"
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
        if index > 0  # Skip first slide as it's already in the cover
          content += "---\n"
          
          # Add layout hints based on content
          if slide.content.length > 5
            content += "layout: two-cols\n"
          end
          
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
          
          unless slide.notes.strip.empty?
            content += "\n<!--\n#{slide.notes}\n-->\n"
          end
          
          content += "\n"
        end
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
