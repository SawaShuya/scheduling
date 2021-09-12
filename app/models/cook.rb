class Cook < ApplicationRecord
  belongs_to :place
  belongs_to :meal
  has_many :schedules

end
