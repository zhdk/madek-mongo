require 'minitest_helper'
require 'minitest/autorun'

class TestMediaSet < MiniTest::Unit::TestCase
  def setup
    @media_resource = @media_set = Media::Set.new
  end

  def test_that_is_a_new_record
    assert_equal true, @media_set.new_record?
  end

  def test_that_has_a_nested_resources_collection
    assert_equal false, @media_set.media_resources.nil?
  end

  def test_that_does_not_have_nested_resources_yet
    assert_equal true, @media_set.media_resources.empty?
  end

  def test_that_could_have_individual_contexts
    assert_equal true, @media_set.individual_contexts.empty?
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
