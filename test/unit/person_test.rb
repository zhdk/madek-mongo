require 'minitest_helper'
require 'minitest/autorun'

class TestPerson < MiniTest::Unit::TestCase
  def setup
    @subject = @person = Person.new
  end

  def test_that_is_a_new_record
    assert_equal true, @person.new_record?
  end

  def test_that_does_not_belong_to_any_group_yet
    assert_equal true, @person.groups.empty?
  end
  
  def test_that_saves_correctly_when_valid
    assert_equal true, @person.valid?
    assert_equal true, @person.save
  end

  
end
