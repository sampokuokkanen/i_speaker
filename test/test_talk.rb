# frozen_string_literal: true

require "test_helper"
require "tempfile"

class TestTalk < Minitest::Test
  def setup
    @talk = ISpeaker::Talk.new(
      title: "Test Talk",
      description: "A test talk",
      target_audience: "Developers",
      duration_minutes: 30,
    )
  end

  def test_talk_initialization
    assert_equal("Test Talk", @talk.title)
    assert_equal("A test talk", @talk.description)
    assert_equal("Developers", @talk.target_audience)
    assert_equal(30, @talk.duration_minutes)
    assert_empty(@talk.slides)
  end

  def test_add_slide
    slide = @talk.add_slide
    assert_equal(1, @talk.slide_count)
    assert_equal(1, slide.number)
    assert_includes(@talk.slides, slide)
  end

  def test_add_slide_with_existing_slide
    existing_slide = ISpeaker::Slide.new(title: "Existing")
    slide = @talk.add_slide(existing_slide)
    assert_equal(existing_slide, slide)
    assert_equal(1, slide.number)
  end

  def test_remove_slide
    @talk.add_slide
    slide2 = @talk.add_slide
    @talk.add_slide

    removed = @talk.remove_slide(1)
    assert_equal(slide2, removed)
    assert_equal(2, @talk.slide_count)

    # Check renumbering
    assert_equal(1, @talk.slides[0].number)
    assert_equal(2, @talk.slides[1].number)
  end

  def test_move_slide
    slide1 = @talk.add_slide
    slide1.title = "First"

    slide2 = @talk.add_slide
    slide2.title = "Second"

    slide3 = @talk.add_slide
    slide3.title = "Third"

    success = @talk.move_slide(0, 2)
    assert(success)

    assert_equal("Second", @talk.slides[0].title)
    assert_equal("Third", @talk.slides[1].title)
    assert_equal("First", @talk.slides[2].title)

    # Check renumbering
    assert_equal(1, @talk.slides[0].number)
    assert_equal(2, @talk.slides[1].number)
    assert_equal(3, @talk.slides[2].number)
  end

  def test_get_slide
    slide = @talk.add_slide
    retrieved = @talk.get_slide(0)
    assert_equal(slide, retrieved)

    assert_nil(@talk.get_slide(10))
  end

  def test_estimated_duration
    # No slides
    estimated = @talk.estimated_duration
    assert_equal(0, estimated)

    # Add some slides
    5.times { @talk.add_slide }
    estimated = @talk.estimated_duration
    assert(estimated > 0)

    # More slides should increase duration
    15.times { @talk.add_slide }
    longer_estimated = @talk.estimated_duration
    assert(longer_estimated > estimated)
  end

  def test_completion_status
    assert_equal("No slides created yet", @talk.completion_status)

    @talk.add_slide
    assert_equal("0/1 slides completed", @talk.completion_status)

    slide = @talk.slides.first
    slide.title = "Complete Slide"
    slide.add_content("Some content")
    assert_equal("1/1 slides completed", @talk.completion_status)
  end

  def test_save_and_load_from_file
    # Add some content
    slide = @talk.add_slide
    slide.title = "Test Slide"
    slide.add_content("Test content")
    slide.notes = "Test notes"

    # Save to temporary file
    temp_file = Tempfile.new(["test_talk", ".json"])
    temp_file.close

    @talk.save_to_file(temp_file.path)
    assert(File.exist?(temp_file.path))

    # Load from file
    loaded_talk = ISpeaker::Talk.load_from_file(temp_file.path)

    assert_equal(@talk.title, loaded_talk.title)
    assert_equal(@talk.description, loaded_talk.description)
    assert_equal(@talk.target_audience, loaded_talk.target_audience)
    assert_equal(@talk.duration_minutes, loaded_talk.duration_minutes)
    assert_equal(@talk.slide_count, loaded_talk.slide_count)

    # Check slide content
    loaded_slide = loaded_talk.slides.first
    assert_equal(slide.title, loaded_slide.title)
    assert_equal(slide.content, loaded_slide.content)
    assert_equal(slide.notes, loaded_slide.notes)

    temp_file.unlink
  end

  def test_load_from_nonexistent_file
    result = ISpeaker::Talk.load_from_file("nonexistent.json")
    assert_nil(result)
  end

  def test_to_hash
    slide = @talk.add_slide
    slide.title = "Test Slide"

    hash = @talk.to_hash

    assert_equal(@talk.title, hash[:title])
    assert_equal(@talk.description, hash[:description])
    assert_equal(@talk.target_audience, hash[:target_audience])
    assert_equal(@talk.duration_minutes, hash[:duration_minutes])
    assert_equal(1, hash[:slides].length)
    assert(hash[:estimated_duration])
    assert(hash[:completion_status])
  end

  def test_summary
    summary = @talk.summary
    assert_includes(summary, @talk.title)
    assert_includes(summary, @talk.description)
    assert_includes(summary, @talk.target_audience)
    assert_includes(summary, @talk.duration_minutes.to_s)
  end
end
