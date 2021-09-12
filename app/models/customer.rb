class Customer < ApplicationRecord
  belongs_to :style
  has_many :ordered_meals

end
