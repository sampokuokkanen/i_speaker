# frozen_string_literal: true

require "test_helper"

class TestSlide < Minitest::Test
  def setup
    @slide = ISpeaker::Slide.new
  end

  def test_slide_initialization
    slide = ISpeaker::Slide.new(
      title: "Test Slide",
      content: ["Point 1", "Point 2"],
      notes: "Test notes"
    )

    assert_equal("Test Slide", slide.title)
    assert_equal(["Point 1", "Point 2"], slide.content)
    assert_equal("Test notes", slide.notes)
  end

  def test_slide_initialization_with_string_content
    slide = ISpeaker::Slide.new(content: "Single point")
    assert_equal(["Single point"], slide.content)
  end

  def test_add_content
    @slide.add_content("New point")
    assert_includes(@slide.content, "New point")
  end

  def test_add_content_ignores_empty_strings
    @slide.add_content("")
    @slide.add_content("   ")
    @slide.add_content(nil)
    assert_empty(@slide.content)
  end

  def test_remove_content
    @slide.add_content("Point 1")
    @slide.add_content("Point 2")
    @slide.remove_content(0)
    assert_equal(["Point 2"], @slide.content)
  end

  def test_update_content
    @slide.add_content("Original point")
    @slide.update_content(0, "Updated point")
    assert_equal(["Updated point"], @slide.content)
  end

  def test_to_hash
    @slide.title = "Test"
    @slide.add_content("Content")
    @slide.notes = "Notes"

    hash = @slide.to_hash
    assert_equal("Test", hash[:title])
    assert_equal(["Content"], hash[:content])
    assert_equal("Notes", hash[:notes])
  end

  def test_empty?
    assert(@slide.empty?)

    @slide.title = "Title"
    refute(@slide.empty?)
  end

  def test_complete?
    refute(@slide.complete?)

    @slide.title = "Title"
    refute(@slide.complete?)

    @slide.add_content("Content")
    assert(@slide.complete?)
  end

  def test_display_summary
    @slide.title = "Test Slide"
    @slide.add_content("Point 1")
    @slide.add_content("Point 2")

    summary = @slide.display_summary
    assert_includes(summary, "Test Slide")
    assert_includes(summary, "(2 points)")
  end
end
