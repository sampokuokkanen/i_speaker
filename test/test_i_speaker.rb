# frozen_string_literal: true

require "test_helper"

class TestISpeaker < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil(::ISpeaker::VERSION)
  end

  def test_module_exists
    assert(defined?(ISpeaker))
  end

  def test_required_classes_exist
    assert(defined?(ISpeaker::Talk))
    assert(defined?(ISpeaker::Slide))
    assert(defined?(ISpeaker::AIPersona))
    assert(defined?(ISpeaker::SampleTalks))
    assert(defined?(ISpeaker::ConsoleInterface))
  end
end
