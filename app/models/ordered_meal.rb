class OrderedMeal < ApplicationRecord
  belongs_to :customer
  belongs_to :meal
  has_many :schedules, dependent: :destroy

  def self.finish_all?
    OrderedMeal.where(actual_served_time: nil, is_rescheduled: false).blank?
  end

  def self.time_satisfaction
    sum = 0
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

    (self.meal.eating_time * self.customer.style.velocity_params * individual_velocity).round
  end
  def actual_interval
    individual_velocity =  actual_velocity_params

    (self.meal.interval * self.customer.style.velocity_params * individual_velocity).round
  end

  def next_timing(average_velocity = 0)
    if average_velocity == 0
      actual_eating_time + actual_interval
    else
      (meal.eating_time + meal.interval) * average_velocity
    end 
  end


  def average_velocity
    finished_meals = self.customer.ordered_meals.where(id: 0..self.id)
    finished_meals.each_with_index do |ordered_meal, i|
      sum = 0 if sum.blank?
      sum += ordered_meal.actual_velocity_params

      if finished_meals[i+1].blank?
         @average =  (sum / (i + 1)).round
      end
    end

    return @average
  end

  def check_time
    if actual_served_time.present?
      self.actual_served_time + self.actual_eating_time * 60 / 2
    end
  end

  def self.check_pace(time)
    ordered_meals = self.where(is_rescheduled: false).where.not(actual_served_time: nil)
    ordered_meals.each_with_index do |ordered_meal, j|
      if ordered_meal.check_time == time
        average_velocity = ordered_meal.average_velocity
        customer_meals = ordered_meal.customer.ordered_meals.where(is_rescheduled: false, is_started: false).or(OrderedMeal.where(id: ordered_meal.id)).sort
        customer_meals.each_with_index do |customer_meal, i|
          if customer_meals[i+1].present?
            if i == 0
              next_ideal_serve_time = customer_meal.actual_served_time + customer_meal.next_timing * 60
            else
              next_ideal_serve_time = customer_meal.ideal_served_time + customer_meal.next_timing(average_velocity) * 60
              # next_ideal_serve_time = customer_meal.ideal_served_time + customer_meal.next_timing * 60
            end
            OrderedMeal.reschedule_ordered_meal(customer_meals[i+1], next_ideal_serve_time)
            customer_meals[i+1].update(is_rescheduled: true, reschedule_time: time)
          end
        end
        Schedule.rescheduling(time)
      end
    end
  end

  def self.reschedule_ordered_meal(next_ordered_meal, next_ideal_serve_time)
    new_ordered_meal_params = next_ordered_meal.attributes.reject{|key, value| key == "id" || key == "created_at" || key == "updated_at" || key == "ideal_served_time"}
    new_ordered_meal_params.merge!({ideal_served_time: next_ideal_serve_time})
    OrderedMeal.create!(new_ordered_meal_params)
  end
end
