# frozen_string_literal: true

module ISpeaker
  class AIPersona
    PERSONA = <<~PERSONA
      You are an expert presentation coach and content creator who specializes in helping people create engaging, well-structured talks. Your role is to:

      1. Help break down complex topics into digestible slides
      2. Suggest compelling slide titles and content
      3. Ensure logical flow between slides
      4. Recommend appropriate examples, analogies, and stories
      5. Adapt content for the target audience
      6. Suggest interactive elements when appropriate

      Your communication style is:
      - Encouraging and supportive
      - Clear and concise
      - Focused on practical advice
      - Mindful of time constraints (typical talks are 15-45 minutes)

      When creating slides, consider:
      - One main idea per slide
      - Strong opening and closing
      - Clear transitions between concepts
      - Engaging visuals (when describing content)
      - Audience engagement opportunities

      Always ask clarifying questions when the talk topic or audience isn't clear.
    PERSONA

    def self.system_prompt
      PERSONA
    end

    def self.slide_creation_prompt(talk_title, talk_description, slide_number, previous_slides = [])
      previous_context = if previous_slides.any?
        "Previous slides in this talk:\n#{previous_slides.map.with_index(1) { |slide, i| "#{i}. #{slide[:title]}" }.join("\n")}\n\n"
      else
        ""
      end

      <<~PROMPT
        #{previous_context}I'm creating slide #{slide_number} for a talk titled "#{talk_title}".

        Talk description: #{talk_description}

        Please suggest:
        1. A compelling title for this slide
        2. 3-5 key bullet points or main content ideas
        3. Any recommended examples, stories, or analogies
        4. Transition suggestions from the previous slide (if applicable)

        Keep the content engaging and appropriate for the flow of the presentation.
      PROMPT
    end

    def self.slide_improvement_prompt(slide_title, slide_content, feedback = nil)
      feedback_context = feedback ? "\n\nSpecific feedback to address: #{feedback}" : ""

      <<~PROMPT
        Please help improve this slide:

        Title: #{slide_title}
        Content: #{slide_content}#{feedback_context}

        Suggest improvements for:
        1. Clarity and impact of the title
        2. Structure and flow of content
        3. Engagement and audience connection
        4. Any missing elements that would strengthen the slide

        Provide specific, actionable suggestions.
      PROMPT
    end
  end
end
