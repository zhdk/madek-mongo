require 'minitest_helper'
require 'minitest/autorun'

class TestGroup < MiniTest::Unit::TestCase
  def setup
    @group = Group.new
  end

  def test_that_is_a_new_record
    assert_equal true, @group.new_record?
  end

  def test_that_has_a_people_collection
    assert_equal false, @group.people.nil?
  end

  def test_that_does_not_have_any_person_yet
    assert_equal true, @group.people.empty?
  end
  
  def test_that_is_not_valid_because_name_is_missing
    @group.name = nil
    assert_equal nil, @group.name
    assert_equal false, @group.valid?
  end

  def test_setting_the_name
    @group.name = "My test group"
    assert_equal "My test group", @group.name
  end
  
  def test_that_saves_correctly_when_valid
    test_setting_the_name
    assert_equal true, @group.valid?
    assert_equal true, @group.save
  end

  def test_that_is_persistent
    test_that_saves_correctly_when_valid
    assert_equal @group, Group.find(@group.id)
  end  
  
#  def test_that_after_save_the_people_collection_is_correct
#    test_that_saves_correctly_when_valid
#    test_that_has_a_people_collection
#    test_that_does_not_have_any_person_yet
#  end

  #def test_that_setting_up_a_collection_of_people_is_working
  #  @group.people = [Ramon, Franco]
  #end
  
end
