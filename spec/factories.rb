
FactoryGirl.define do

  factory :person do
    firstname {Faker::Name.first_name}
    lastname {Faker::Name.last_name}
    email {"#{firstname}.#{lastname}@example.com".downcase} 
    login {"#{firstname}_#{lastname}".downcase} 
  end

  factory :group do
  end
   
end
