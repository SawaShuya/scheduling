class OrderedMeal < ApplicationRecord
  belongs_to :customer
  belongs_to :meal
  has_many :schedules, dependent: :destroy

  def self.finish_all?
    OrderedMeal.where(actual_served_time: nil).blank?
  end

  def self.time_satisfaction
    sum = 0
    self.all.each do |ordered_meal|
      if self.finish_all?
        surve_time = ordered_meal.actual_served_time
      else
        surve_time = ordered_meal.schedules.first.end_time
      end
      sum += ((ordered_meal.ideal_served_time - surve_time)/60) ** 2
      # byebug
    end

    return sum
  end

  def actual_eating_time
    individual_velocity =  self.customer.velocity_params

    (self.meal.eating_time * self.customer.style.velocity_params * individual_velocity).round
  end
  def actual_interval
    individual_velocity =  self.customer.velocity_params

    (self.meal.interval * self.customer.style.velocity_params * individual_velocity).round
  end

  def next_timing
    actual_eating_time + actual_interval
  end

  def check_time
    if actual_served_time.present?
      self.actual_served_time + self.actual_eating_time * 60 / 2
    end
  end

  def self.check_pace(time)
    ordered_meals = self.where.not(actual_served_time: nil)
    # byebug
    ordered_meals.each_with_index do |ordered_meal, j|
      # if ordered_meal.check_time == time && ordered_meals[j+1].present? && ordered_meal.customer == ordered_meals[j+1].customer
      if ordered_meal.check_time == time
        customer_meals = ordered_meal.customer.ordered_meals.where(id: ordered_meal.id..ordered_meal.customer.ordered_meals.last.id)
        customer_meals.each_with_index do |customer_meal, i|
          if customer_meals[i+1].present?
            if i == 0
              next_ideal_serve_time = customer_meal.actual_served_time + customer_meal.next_timing * 60
              customer_meals[i+1].update(ideal_served_time: next_ideal_serve_time)
              # byebug
            elsif i != customer_meals.count - 1
              next_ideal_serve_time = customer_meal.ideal_served_time + customer_meal.next_timing * 60
              customer_meals[i+1].update(ideal_served_time: next_ideal_serve_time)
            end
          end
        end
        Schedule.rescheduling(time)
      end
    end

  end

  
  
end
