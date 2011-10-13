=begin
require 'minitest/autorun'

class TestMediaSet < MiniTest::Unit::TestCase
  def setup
    @media_set = Media::Set.new
  end

  def test_that_does_not_have_nested_resources
    assert_equal true, @media_set.media_resources.nil?
  end
  
end
=end