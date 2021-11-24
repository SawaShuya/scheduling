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

  def add_actual_velocity_params
    (self.velocity_params + rand(-0.15...0.15).round(1)).round(1)
  end

  def self.set_actual_visit_time(reserve_time)
    range = -5..5
    # actual_visit_time = (reserve_time + rand(range) * 60).round
    actual_visit_time = (reserve_time).round
    return actual_visit_time
  end

  def self.create_samples
    customer_number = 3
    velocity_range = 0.8..1.2
    open_time = Time.mktime(2020, 1, 1, 17, 0,0,6)
    reserve_timing = [0, 15, 30, 45, 60]

    customer_number.times do |i|
      time = open_time + reserve_timing[rand(0..4)]*60
      customer = Customer.new(style_id: rand(1..3), velocity_params: rand(velocity_range).round(1), reserved_time: time.round, actual_visit_time: set_actual_visit_time(time))
      if customer.save!
        customer.create_ordered_meals(customer.reserved_time)
      end
    end
  end

  def create_ordered_meals(start_time)
    first_interval = 15
    meals = Meal.all
    next_serve_time = start_time + first_interval * 60
    meals.each do |meal|
      order_meal = self.ordered_meals.new(meal_id: meal.id, ideal_served_time: next_serve_time.round, is_started: false, is_rescheduled: false, actual_velocity_params: self.add_actual_velocity_params, average_velocity_params: self.style.velocity_params)
      order_meal.save
      next_serve_time += ((meal.eating_time + meal.interval) * self.style.velocity_params).round * 60
    end
  end

  def self.create_all_ordered_meals
    self.all.each do |customer|
      customer.create_ordered_meals(customer.reserved_time)
    end
  end

  def self.check_visit(time)
    @is_necessity = false
    if self.all.maximum(:actual_visit_time) >= time.round 
      customers = self.where('actual_visit_time = ?', time.round)
      if customers.present?
        customers.each do |customer|
          if customer.has_difference_visit_time?(time)
            customer.ordered_meals.update_all(is_rescheduled: true, reschedule_time: time.round)
            customer.create_ordered_meals(time.round)
            @is_necessity = true
          end
        end
      end
    end
    return @is_necessity
  end

  def has_difference_visit_time?(time)
    self.reserved_time.round != time.round
  end

  def is_visited?(time)
    time > self.actual_visit_time
  end
end
