require 'minitest_helper'
require 'minitest/autorun'

class TestMediaEntry < MiniTest::Unit::TestCase
  def setup
    @media_resource = @media_entry = Media::Entry.new
  end

  def test_that_is_a_new_record
    assert_equal true, @media_entry.new_record?
  end

  ################################################
  # common for media_resources
  
  def test_that_as_resource_has_an_empty_meta_data_collection
    assert_equal false, @media_resource.meta_data.nil?
    assert_equal true, @media_resource.meta_data.empty?
  end

  def test_that_as_resource_has_an_embedded_permission
    assert_equal false, @media_resource.permission.nil?
    assert_equal true, @media_resource.permission.is_a?(Permission)
  end

  def test_that_does_not_belong_to_any_set_yet
    assert_equal true, @media_resource.media_sets.empty?
  end

end
