class OrderedMeal < ApplicationRecord
  belongs_to :customer
  belongs_to :meal
end
