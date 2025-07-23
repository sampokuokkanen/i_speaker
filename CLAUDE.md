# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

i_speaker is an AI-powered Ruby gem for creating compelling presentations slide by slide. It provides an interactive console interface with intelligent AI assistance through both local Ollama models and cloud-based AI services.

## Essential Commands

```bash
# Install dependencies
bin/setup

# Run tests
rake test

# Run linter
rake rubocop

# Run tests and linter (default)
rake

# Run a single test file
ruby -Ilib:test test/test_talk.rb

# Build the gem
bundle exec rake build

# Install locally
bundle exec rake install

# Start development console
bin/console

# Run the application
exe/i_speaker

# Run demo scripts
ruby demo_complete.rb
```

## Architecture

The codebase follows a clean module structure under `ISpeaker`:

- **Talk** (`lib/i_speaker/talk.rb`): Main presentation container managing slides, metadata, and serialization
- **Slide** (`lib/i_speaker/slide.rb`): Individual slide with title, content points, and speaker notes  
- **ConsoleInterface** (`lib/i_speaker/console_interface.rb`): Interactive CLI using TTY::Prompt with dual AI integration
- **OllamaClient** (`lib/i_speaker/ollama_client.rb`): Direct integration with local Ollama API for offline AI capabilities
- **AIPersona** (`lib/i_speaker/ai_persona.rb`): AI prompts and configuration for intelligent suggestions
- **SampleTalks** (`lib/i_speaker/sample_talks.rb`): Pre-built presentation templates

## Key Features

1. **Dual AI Support**: Automatically detects and uses local Ollama if available, falls back to RubyLLM for cloud APIs
2. **Complete Talk Generation**: AI-guided workflow that asks clarifying questions and generates entire presentations
3. **Multiple Export Formats**: Standard markdown, Slidev presentations, plain text, and JSON
4. **Smart Slide Creation**: Context-aware slide generation based on talk topic and previous slides
5. **Enhanced File Loading**: Intelligent file browser showing talk previews, metadata, and modification times
6. **Auto-Save Protection**: Automatic saving after every change with graceful exit handling to prevent data loss

## Key Development Notes

1. **Ruby Version**: Requires Ruby 3.1.0+
2. **Testing**: Uses Minitest with comprehensive unit tests for all classes
3. **Code Style**: Enforces double quotes for strings via RuboCop
4. **AI Dependencies**: 
   - Primary: Direct Ollama integration (no external dependencies)
   - Fallback: RubyLLM gem for cloud AI services
   - Runtime: TTY::Prompt and Colorize for UI
5. **CI/CD**: GitHub Actions runs tests and linting on push to main and PRs

## AI Configuration

The gem supports multiple AI backends:

1. **Local Ollama** (preferred): Automatically detected if running on localhost:11434
2. **RubyLLM with various providers**: OpenAI, Anthropic, Gemini, etc.
3. **Graceful degradation**: Works without AI if neither is available

## Working with the Code

When modifying this codebase:
- All classes must be namespaced under `ISpeaker`
- AI functionality should work through the `ai_ask` method in ConsoleInterface
- Follow existing patterns for error handling with clear user messages
- Always create Talk objects before AI processing to prevent nil reference errors
- Use robust JSON parsing that can extract JSON from mixed AI responses
- Provide graceful fallbacks when AI features fail
- Call `auto_save` after major operations that modify talk state
- Handle signals gracefully to prevent data loss on unexpected exit
- Maintain test coverage for new functionality
- Use TTY::Prompt for any new interactive features
- Export functionality should be added to ConsoleInterface with descriptive format names

## Slidev Integration

The gem can export presentations as Slidev-compatible markdown files with:
- Proper frontmatter configuration
- Automatic layout selection based on content
- Speaker notes as HTML comments
- Two-column layouts for content-heavy slides