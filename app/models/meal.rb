class Meal < ApplicationRecord
  has_many :cooks
  has_many :ordered_meals
end
