require 'spec_helper'

describe Person do

  it "should valid when created by default factory" do 
    (FactoryGirl.create :person).should be_valid 
  end

end
