class OrderedMeal < ApplicationRecord
  belongs_to :customer
  belongs_to :meal
  has_many :schedules, dependent: :destroy
end
