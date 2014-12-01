FactoryGirl.define do
  factory :user do
    email "hoge@example.com"
    uuid "this-is-uuid"
    password "password"
    password_confirmation "password"
  end
end

