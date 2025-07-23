# frozen_string_literal: true

module ISpeaker
  class SampleTalks
    SAMPLE_TALKS = [
      {
        title: "Introduction to Ruby on Rails",
        description: "A beginner-friendly overview of the Ruby on Rails framework for web development",
        slides: [
          {
            title: "Welcome to Ruby on Rails",
            content: [
              "What is Ruby on Rails?",
              "Why developers love Rails",
              "What we'll cover today",
              "Let's build something amazing together!",
            ],
          },
          {
            title: "The Rails Philosophy",
            content: [
              "Convention over Configuration",
              "Don't Repeat Yourself (DRY)",
              "The beauty of opinionated software",
              "How this speeds up development",
            ],
          },
          {
            title: "MVC Architecture Made Simple",
            content: [
              "Models: Your data layer",
              "Views: What users see",
              "Controllers: The traffic directors",
              "How they work together seamlessly",
            ],
          },
        ],
      },
      {
        title: "Effective Team Communication",
        description: "Strategies for improving communication within software development teams",
        slides: [
          {
            title: "The Communication Challenge",
            content: [
              "Why communication breaks down",
              "Cost of miscommunication",
              "The remote work factor",
              "Setting the stage for improvement",
            ],
          },
          {
            title: "Active Listening Techniques",
            content: [
              "Listen to understand, not to respond",
              "Ask clarifying questions",
              "Paraphrase what you heard",
              "Practice: The 2-minute rule",
            ],
          },
          {
            title: "Documentation That Actually Helps",
            content: [
              "Write for your future self",
              "The 'why' is as important as the 'what'",
              "Keep it updated and relevant",
              "Tools that make it easier",
            ],
          },
        ],
      },
      {
        title: "Getting Started with AI in Development",
        description: "Practical applications of AI tools in software development workflows",
        slides: [
          {
            title: "AI is Here to Stay",
            content: [
              "Current state of AI in development",
              "Opportunities, not threats",
              "What's possible today",
              "Your journey starts now",
            ],
          },
          {
            title: "Code Generation and Completion",
            content: [
              "GitHub Copilot and similar tools",
              "Best practices for AI pair programming",
              "When to trust, when to verify",
              "Maintaining code quality",
            ],
          },
          {
            title: "Beyond Code: AI for Everything Else",
            content: [
              "Documentation generation",
              "Test case creation",
              "Code review assistance",
              "Project planning and estimation",
            ],
          },
        ],
      },
    ].freeze

    def self.all
      SAMPLE_TALKS
    end

    def self.find_by_topic(topic)
      SAMPLE_TALKS.select do |talk|
        talk[:title].downcase.include?(topic.downcase) ||
          talk[:description].downcase.include?(topic.downcase)
      end
    end

    def self.random_example
      SAMPLE_TALKS.sample
    end

    def self.sample_context_for_ai
      examples = SAMPLE_TALKS.first(2).map do |talk|
        slides_summary = talk[:slides].map.with_index(1) do |slide, i|
          "#{i}. #{slide[:title]}: #{slide[:content].join(", ")}"
        end.join("\n")

        "Example Talk: #{talk[:title]}\n#{talk[:description]}\nSlides:\n#{slides_summary}"
      end

      "Here are some examples of well-structured talks:\n\n#{examples.join("\n\n")}"
    end
  end
end
