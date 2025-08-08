# frozen_string_literal: true

require_relative "lib/i_speaker/version"

Gem::Specification.new do |spec|
  spec.name = "i_speaker"
  spec.version = ISpeaker::VERSION
  spec.authors = ["Sampo Kuokkanen"]
  spec.email = ["sampo.kuokkanen@gmail.com"]

  spec.summary = "AI-powered talk creation tool that helps you build presentations slide by slide."
  spec.description = "i_speaker is a gem that helps you create talks slide by slide about any topic using AI through RubyLLM. It provides a console interface for iterative talk development."
  spec.homepage = "https://github.com/sampokuokkanen/i_speaker"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sampokuokkanen/i_speaker"
  spec.metadata["changelog_uri"] = "https://github.com/sampokuokkanen/i_speaker/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "async", "~> 2.0"
  spec.add_dependency "async-http", "~> 0.75"
  spec.add_dependency "colorize", "~> 0.8"
  spec.add_dependency "nokogiri", "~> 1.0"
  spec.add_dependency "ruby_llm", "~> 1.3"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-spinner", "~> 0.9"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
