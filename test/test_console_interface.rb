# frozen_string_literal: true

require "test_helper"

class TestConsoleInterface < Minitest::Test
  def setup
    @interface = ISpeaker::ConsoleInterface.new
  end

  def test_console_interface_initialization
    # Test that interface can be created without errors
    assert_instance_of(ISpeaker::ConsoleInterface, @interface)
  end

  def test_console_interface_responds_to_start
    assert_respond_to(@interface, :start)
  end

  # NOTE: Full console interface testing would require mocking TTY::Prompt
  # and simulating user input, which is complex. These basic tests ensure
  # the class can be instantiated and has the expected interface.
end
