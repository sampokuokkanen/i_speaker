#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to showcase Review and Fix Structure capabilities

require_relative 'lib/i_speaker'

puts "🔍 Review and Fix Structure Demo".cyan.bold
puts "=" * 50

puts "\n📋 Demo Overview:".yellow
puts "This demo shows how the Review and Fix Structure feature helps identify"
puts "and automatically fix common presentation structure problems."

puts "\nKey features:".blue
puts "• 10 categories of structural issues to focus on"
puts "• AI analyzes presentation structure in detail"
puts "• Automatically detects and categorizes issues"
puts "• Provides actionable fixes with severity levels"
puts "• Can apply simple fixes automatically"

# Create a sample talk with structural issues
puts "\n🎯 Creating a sample presentation with structural issues...".yellow

talk = ISpeaker::Talk.new(
  title: "Machine Learning in Production",
  description: "An overview of deploying ML models in production environments",
  target_audience: "Software engineers",
  duration_minutes: 45
)

# Add slides with intentional structural problems
problem_slides = [
  { title: "Machine Learning in Production", content: ["What is ML?", "Why production?", "My background"] },
  { title: "Types of ML Models", content: ["Supervised learning", "Unsupervised learning", "Reinforcement learning"] },
  { title: "Data Preprocessing", content: ["Clean data", "Feature engineering", "Validation splits"] },
  { title: "Model Training", content: ["Choose algorithm", "Train model", "Evaluate performance"] },
  { title: "Deployment Strategies", content: ["Blue-green", "Canary", "Rolling updates"] },
  { title: "Monitoring", content: ["Model drift", "Performance metrics", "Alerting"] },
  { title: "Conclusion", content: ["Summary", "Questions?"] }
]

problem_slides.each do |slide_data|
  slide = ISpeaker::Slide.new(
    title: slide_data[:title],
    content: slide_data[:content],
    notes: "Basic speaker notes for #{slide_data[:title]}"
  )
  talk.add_slide(slide)
end

puts "✅ Created problematic talk: \"#{talk.title}\"".green
puts "   Duration: #{talk.duration_minutes} minutes".light_blue
puts "   Current slides: #{talk.slides.length}".light_blue

# Show the structural issues
puts "\n⚠️  Structural Issues in This Presentation:".red.bold

issues = [
  {
    category: "Pacing",
    description: "Only 7 slides for 45 minutes (6.4 min/slide - too slow!)",
    severity: "HIGH"
  },
  {
    category: "Introduction Structure",
    description: "Missing agenda, objectives, and proper introduction flow",
    severity: "HIGH"
  },
  {
    category: "Flow & Transitions",
    description: "Abrupt jumps between topics without transitions",
    severity: "MEDIUM"
  },
  {
    category: "Examples & Case Studies",
    description: "No practical examples or real-world case studies",
    severity: "HIGH"
  },
  {
    category: "Interactive Elements",
    description: "No Q&A breaks, exercises, or audience engagement",
    severity: "MEDIUM"
  },
  {
    category: "Content Depth",
    description: "Complex topics covered too briefly",
    severity: "HIGH"
  },
  {
    category: "Engagement",
    description: "Risk of losing audience in long 45-minute session",
    severity: "MEDIUM"
  }
]

issues.each_with_index do |issue, i|
  color = case issue[:severity]
         when "HIGH" then :red
         when "MEDIUM" then :yellow
         when "LOW" then :light_blue
         end
  
  puts "\n#{i + 1}. #{issue[:description]}".send(color)
  puts "   Category: #{issue[:category]}".light_blue
  puts "   Severity: #{issue[:severity]}".send(color)
end

# Show what Review and Fix would detect and fix
puts "\n🔍 Review and Fix Analysis Process:".cyan.bold

puts "\n1. User Input Collection:".blue
puts "   ✓ Select focus areas from 10 categories:"
puts "     • Flow and transitions between slides"
puts "     • Missing introduction/conclusion structure"
puts "     • Slide count vs duration (pacing)"
puts "     • Missing examples or case studies"
puts "     • Lack of interactive elements"
puts "     • Content depth and balance"
puts "     • Audience engagement opportunities"
puts "     • Technical accuracy and completeness"
puts "     • Repetition or redundant content"
puts "     • Overall presentation coherence"

puts "\n   ✓ Specific issues input:"
puts "     \"The presentation feels too high-level and rushed.\""
puts "     \"Need more practical examples for engineers.\""

puts "\n   ✓ Target outcome:"
puts "     \"Help engineers understand practical ML deployment challenges\""

puts "\n2. AI Analysis Results:".blue

sample_analysis = {
  "issues_found" => [
    {
      "category" => "pacing",
      "severity" => "high",
      "description" => "7 slides for 45 minutes results in 6.4 minutes per slide, which is too slow for technical content",
      "affected_slides" => [1,2,3,4,5,6,7],
      "impact" => "Audience will lose focus, content will feel rushed at the end"
    },
    {
      "category" => "structure",
      "severity" => "high", 
      "description" => "Missing proper introduction structure with agenda and learning objectives",
      "affected_slides" => [1],
      "impact" => "Audience won't know what to expect or why they should care"
    },
    {
      "category" => "content",
      "severity" => "high",
      "description" => "Complex topics like model training and monitoring need more detailed explanation",
      "affected_slides" => [4,6],
      "impact" => "Engineers won't have enough practical guidance to apply concepts"
    },
    {
      "category" => "engagement",
      "severity" => "medium",
      "description" => "No interactive elements or practical exercises for a 45-minute technical session",
      "affected_slides" => [],
      "impact" => "Risk of audience disengagement during long session"
    }
  ],
  "fixes" => [
    {
      "type" => "add_slide",
      "description" => "Add agenda and learning objectives slide after introduction",
      "action" => "Insert detailed agenda slide with clear learning outcomes",
      "position" => "after_slide_1",
      "new_content" => {
        "title" => "Agenda & Learning Objectives",
        "content" => [
          "What you'll learn today",
          "ML deployment pipeline overview", 
          "Hands-on deployment strategies",
          "Real-world monitoring examples",
          "Q&A and discussion"
        ],
        "notes" => "Set expectations and engage audience by showing practical value"
      }
    },
    {
      "type" => "add_slide",
      "description" => "Add real-world case study examples throughout",
      "action" => "Insert case study slides showing actual deployment scenarios",
      "position" => "after_slide_4",
      "new_content" => {
        "title" => "Case Study: Netflix Recommendation Engine",
        "content" => [
          "Challenge: 100M+ users, real-time predictions",
          "Solution: A/B testing framework for models", 
          "Implementation: Canary deployments with automatic rollback",
          "Results: 20% improvement in engagement",
          "Lessons learned"
        ],
        "notes" => "Concrete example engineers can relate to and learn from"
      }
    }
  ],
  "overall_assessment" => "The presentation covers important topics but needs significant structural improvements. Priority fixes: expand slide count, add practical examples, improve introduction structure, and include interactive elements for better engagement."
}

puts "\n📊 Analysis Results Display:".green

puts "\n🔍 Issues Found:".red.bold
sample_analysis["issues_found"].each_with_index do |issue, i|
  severity_color = case issue["severity"]
                  when "high" then :red
                  when "medium" then :yellow
                  when "low" then :light_blue
                  else :white
                  end
  
  puts "\n#{i + 1}. #{issue['description']}".send(severity_color)
  puts "   Category: #{issue['category'].capitalize}".light_blue
  puts "   Severity: #{issue['severity'].upcase}".send(severity_color)
  puts "   Affects slides: #{issue['affected_slides'].join(', ')}".light_blue
  puts "   Impact: #{issue['impact']}".light_blue
end

puts "\n🛠️  Suggested Fixes:".green.bold
sample_analysis["fixes"].each_with_index do |fix, i|
  puts "\n#{i + 1}. #{fix['description']}".green
  puts "   Type: #{fix['type'].gsub('_', ' ').capitalize}".light_blue
  puts "   Action: #{fix['action']}".light_blue
  puts "   Position: #{fix['position']}".light_blue
  puts "   New slide: \"#{fix.dig('new_content', 'title')}\"".light_green if fix.dig('new_content', 'title')
end

puts "\n📋 Overall Assessment:".cyan.bold
puts sample_analysis["overall_assessment"].light_blue

# Show the fix application process
puts "\n🔧 Fix Application Process:".yellow.bold

puts "\n3. Automated Fix Application:".blue
puts "   User confirms: \"Yes, apply the suggested fixes\""

puts "\n   🔧 Applying fixes..."
puts "   ✅ Added slide: \"Agenda & Learning Objectives\""
puts "   ✅ Added slide: \"Case Study: Netflix Recommendation Engine\""
puts "   ⚠️  Slide reordering requires manual action"
puts "   ⚠️  Content expansion requires manual review"

puts "\n   🎉 Applied 2/4 fixes successfully!"
puts "   Your presentation structure has been improved."

# Show the improved structure
puts "\n📈 Improved Structure:".green.bold

improved_structure = [
  "1. Machine Learning in Production (title slide)",
  "2. Agenda & Learning Objectives (NEW)",
  "3. Types of ML Models",
  "4. Data Preprocessing", 
  "5. Model Training",
  "6. Case Study: Netflix Recommendation Engine (NEW)",
  "7. Deployment Strategies",
  "8. Monitoring",
  "9. Conclusion"
]

puts "\nBefore: 7 slides → After: 9 slides".blue
improved_structure.each do |slide|
  color = slide.include?("(NEW)") ? :green : :light_blue
  puts "   #{slide}".send(color)
end

# Benefits and usage
puts "\n✨ Benefits of Review and Fix:".green.bold
puts "• Identifies specific structural problems"
puts "• Provides actionable, prioritized fixes"
puts "• Automatically applies simple improvements"
puts "• Guides manual fixes for complex issues"
puts "• Improves presentation effectiveness"

puts "\n💡 Types of Issues Detected:".blue.bold

issue_categories = [
  { name: "Flow Issues", examples: ["Logical order problems", "Missing transitions", "Abrupt topic changes"] },
  { name: "Pacing Problems", examples: ["Too few/many slides", "Uneven time distribution", "Rush/drag sections"] },
  { name: "Structure Gaps", examples: ["Weak introduction", "Missing conclusion", "No agenda/objectives"] },
  { name: "Content Issues", examples: ["Too shallow/deep", "Missing examples", "Redundant content"] },
  { name: "Engagement Problems", examples: ["No interactivity", "Long passive sections", "No Q&A breaks"] }
]

issue_categories.each do |category|
  puts "\n#{category[:name]}:".yellow
  category[:examples].each { |example| puts "   • #{example}".light_blue }
end

puts "\n🎯 Best Practices:".cyan.bold
puts "• Run Review and Fix after creating initial structure"
puts "• Focus on 3-4 key areas rather than trying to fix everything"
puts "• Review AI suggestions before applying fixes"
puts "• Use in combination with AI Fix Mode for complete presentations"
puts "• Run again after major content changes"

puts "\n🚀 Usage Flow:".green.bold
puts "1. Create or load your presentation"
puts "2. Go to AI assistance → \"Review and Fix Structure\""  
puts "3. Select focus areas (flow, pacing, examples, etc.)"
puts "4. Describe specific issues you've noticed"
puts "5. Set your presentation goal"
puts "6. Review AI analysis and suggested fixes"
puts "7. Apply automatic fixes and implement manual suggestions"
puts "8. Review improved structure"

puts "\n✅ Demo complete!".green.bold
puts "Review and Fix Structure helps create more effective presentations".light_blue
puts "by identifying and solving structural problems automatically.".light_blue