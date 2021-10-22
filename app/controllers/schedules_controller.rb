class SchedulesController < ApplicationController
  

  def index
    @chefs = Chef.all
    @customers = Customer.all.includes(:style).sort{|a, b| a.reserved_time <=> b.reserved_time}
    @time_satisfaction = OrderedMeal.time_satisfaction
  end

  def active
    time = ProcessTime.now
    end_time = Schedule.maximum(:end_time).round
    i = 0
    while time <= end_time && i < 300 do
      time = time.round
      necessity_reschedule_for_cook_time = Schedule.every_process(time)
      necessity_reschedule_for_ordered_meals = OrderedMeal.check_pace(time)
      if necessity_reschedule_for_cook_time || necessity_reschedule_for_ordered_meals
        Schedule.rescheduling(time, necessity_reschedule_for_cook_time, necessity_reschedule_for_ordered_meals)
      end

      end_time = Schedule.maximum(:end_time).round
      time += 60
      i += 1
    end
    ProcessTime.first.update(now: end_time.round)
    redirect_to root_path
  end

  def show
    @time = ProcessTime.now
    @chefs = Chef.all
    Schedule.every_process(@time)
    OrderedMeal.check_pace(@time)
  end

  def next_time
    next_time = ProcessTime.now + 60
    ProcessTime.first.update(now: next_time)
    redirect_to moment_path
  end

  def reset_all
    Customer.all.destroy_all
    Chef.reset_work_time
    Customer.create_samples
    ordered_meal_ids = OrderedMeal.all.pluck(:id)
    Schedule.backward_scheduling(nil, false, ordered_meal_ids)
    ProcessTime.set_zero_time
    redirect_to root_path
  end

  def reset_ordered_meal
    OrderedMeal.destroy_all
    Customer.create_all_ordered_meals
    Chef.reset_work_time
    ordered_meal_ids = OrderedMeal.all.pluck(:id)
    Schedule.backward_scheduling(nil, false, ordered_meal_ids)
    ProcessTime.set_zero_time
    redirect_to root_path
  end

end
