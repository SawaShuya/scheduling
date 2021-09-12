class Chef < ApplicationRecord
  has_many :schedules

  def cook_speed
    if skill == 1
      speed = 1.1
    elsif skill == 2
      speed = 1.0
    elsif skill == 3
      speed = 0.9
    end
    return speed
  end
end
