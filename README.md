# ISpeaker 🎤

An AI-powered talk creation tool that helps you build compelling presentations slide by slide. ISpeaker uses AI through RubyLLM to provide intelligent suggestions, structure guidance, and content improvements for your talks.

## Features

- **AI-Powered Assistance**: Get intelligent suggestions for slide content, structure, and improvements
- **Step-by-Step Process**: Build your talk incrementally with guided workflows
- **Sample Templates**: Learn from curated sample talks across different topics
- **Interactive Console**: Easy-to-use command-line interface with full editing capabilities
- **Multiple Export Formats**: Save your talks as JSON, Markdown, or plain text
- **Rewrite and Iterate**: Easily modify any part of your talk at any time

## Installation

Install the gem by executing:

```bash
gem install i_speaker
```

Or add it to your Gemfile:

```ruby
gem 'i_speaker'
```

Then run `bundle install`.

## Usage

### Starting the Application

Launch the interactive console:

```bash
i_speaker
```

Or use the console command:

```bash
bin/console
```

### Creating Your First Talk

1. **Start the application** - Choose "Create a new talk"
2. **Enter talk details**:

   - Title of your talk
   - Description and key messages
   - Target audience
   - Expected duration

3. **Build slides step by step**:

   - Create slides manually or with AI assistance
   - Edit titles, content points, and speaker notes
   - Get AI suggestions for improvements
   - Reorder slides as needed

4. **Review and refine**:

   - Get AI feedback on overall structure
   - Improve individual slides
   - Add presentation tips

5. **Export your talk**:
   - Save as JSON for future editing
   - Export as Markdown or text for presentations

### AI Features

- **Smart Content Generation**: AI suggests slide titles and bullet points based on your talk topic
- **Structure Review**: Get feedback on overall flow and organization
- **Slide Improvements**: AI analyzes individual slides and suggests enhancements
- **Presentation Tips**: Receive delivery advice tailored to your topic and audience

### Sample Talks

Explore built-in sample talks covering:

- Technical topics (Ruby on Rails, AI in Development)
- Soft skills (Team Communication)
- And more...

Use these as inspiration or starting points for your own talks.

## Requirements

- Ruby 3.1.0 or higher
- RubyLLM gem for AI features (optional but recommended)

## AI Setup

To use AI features, you'll need to configure RubyLLM with your preferred AI provider:

```ruby
# Set up your AI provider (OpenAI, Anthropic, etc.)
# Follow RubyLLM documentation for configuration
```

The application will work without AI, but you'll miss out on the intelligent suggestions and improvements.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

### Running Tests

```bash
rake test
```

### Local Installation

To install this gem onto your local machine:

```bash
bundle exec rake install
```

## Project Structure

```
lib/
├── i_speaker.rb              # Main module
├── i_speaker/
│   ├── version.rb            # Version information
│   ├── ai_persona.rb         # AI prompts and persona
│   ├── sample_talks.rb       # Sample talk templates
│   ├── slide.rb              # Slide class
│   ├── talk.rb               # Talk class
│   └── console_interface.rb  # Main user interface
exe/
└── i_speaker                 # Executable script
test/                         # Minitest test suite
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sampokuokkanen/i_speaker.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
