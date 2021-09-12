class Customer < ApplicationRecord
  belongs_to :style
  has_many :ordered_meals, dependent: :destroy

  def speed
    if velocity_params ==  0.8
      '速い'
    elsif velocity_params ==  0.9
      'やや速い'
    elsif velocity_params ==  1.0
      '普通'
    elsif velocity_params ==  1.1
      'やや遅い'
    elsif velocity_params ==  1.2
      '遅い'
    end
  end

end
