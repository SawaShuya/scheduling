class OrderedMeal < ApplicationRecord
  belongs_to :customer
  belongs_to :meal
  has_many :schedules, dependent: :destroy

  def self.finish_all?
    OrderedMeal.where(actual_served_time: nil, is_rescheduled: false).blank?
  end

  def self.time_satisfaction
    sum = 0
    # customer_ids = Customer.all.pluck(:id)
    # meal_ids = Meal.all.pluck(:id)
    # customer_ids.each do |customer_id|
    #   meal_ids.each do |meal_id|
    #     ordered_meal = OrderedMeal.where(meal_id: meal_id, customer_id: customer_id).last
    #     actual_ordered_meal = OrderedMeal.find_by(meal_id: meal_id, customer_id: customer_id, is_rescheduled: false)
    #     # byebug
        
    #     sum += ((ordered_meal.ideal_served_time - actual_ordered_meal.actual_served_time)/60) ** 2
    #   end
    # end
    self.where(is_rescheduled: false).each do |ordered_meal|
      if self.finish_all?
        surve_time = ordered_meal.actual_served_time
      else
        surve_time = ordered_meal.schedules.first.end_time
      end
      sum += ((ordered_meal.ideal_served_time - surve_time)/60) ** 2
    end

    return sum
  end

  def actual_eating_time
    individual_velocity =  actual_velocity_params

    (self.meal.eating_time * individual_velocity).round
  end
  def actual_interval
    individual_velocity =  actual_velocity_params

    (self.meal.interval * individual_velocity).round
  end

  def next_timing(average_velocity = 0)
    if average_velocity == 0
      actual_eating_time + actual_interval
    else
      ((meal.eating_time + meal.interval) * average_velocity).round
    end 
  end


  def average_velocity
    finished_meals = self.customer.ordered_meals.where(id: 0..self.id, is_rescheduled: false, is_started: true)
    sum = 0
    finished_meals.each_with_index do |ordered_meal, i|
      sum += ordered_meal.actual_velocity_params

      if finished_meals[i+1].blank?
         @average =  (sum / (i + 1)).round(2)
      end
    end

    return @average
  end

  def check_time
    if actual_served_time.present?

      self.actual_served_time + (self.actual_eating_time / 2).round * 60
    end
  end

  def self.check_pace(time)
    is_necessity = false
    ordered_meals = self.where(is_rescheduled: false, is_started: true).where.not(actual_served_time: nil)
    ordered_meals.each_with_index do |ordered_meal, j|
      if ordered_meal.check_time.round == time && ordered_meal.meal_id != Meal.all.last.id
        average_velocity = ordered_meal.average_velocity

        customer_meals = ordered_meal.customer.ordered_meals.where(is_rescheduled: false, meal_id: ordered_meal.meal_id..8)
        customer_meals.each_with_index do |customer_meal, i|
          if customer_meals[i+1].present?
            if i == 0
              next_ideal_serve_time = customer_meal.actual_served_time + customer_meal.next_timing(average_velocity) * 60
            else
              next_ideal_serve_time = @last_ordered_meal.ideal_served_time + @last_ordered_meal.next_timing(average_velocity) * 60
            end
            @last_ordered_meal = OrderedMeal.reschedule_ordered_meal(customer_meals[i+1], next_ideal_serve_time, average_velocity)
            customer_meals[i+1].update(is_rescheduled: true, reschedule_time: time)
          end
        end
        is_necessity = true
      end
    end
    return is_necessity
  end

  def self.reschedule_ordered_meal(next_ordered_meal, next_ideal_serve_time, average_velocity)
    new_ordered_meal_params = next_ordered_meal.attributes.reject{|key, value| key == "id" || key == "created_at" || key == "updated_at" || key == "ideal_served_time" || key == "is_started"}
    new_ordered_meal_params.merge!({ideal_served_time: next_ideal_serve_time.round, average_velocity_params: average_velocity, is_started: false})
    # new_ordered_meal_params.merge!({ideal_served_time: next_ideal_serve_time.round, average_velocity_params: average_velocity, is_started: false, is_rescheduled: true})
    ordered_meal = OrderedMeal.new(new_ordered_meal_params)
    ordered_meal.save!
    if next_ordered_meal.is_started
      ordered_meal.update(is_started: true)
    end

    return ordered_meal
  end
end
