class SchedulesController < ApplicationController
  

  def index
    @chefs = Chef.all
    @customers = Customer.all.includes(:style).sort{|a, b| a.reserved_time <=> b.reserved_time}
    @time_satisfaction = OrderedMeal.time_satisfaction
  end

  def active
    time = ProcessTime.now
    end_time = (Schedule.maximum(:end_time) + 600).round
    i = 0
    while time <= end_time && i < 300 do
      time = time.round
      necessity_reschedule_for_visit_time = Customer.check_visit(time)
      necessity_reschedule_for_cook_time = Schedule.every_process(time)
      necessity_reschedule_for_ordered_meals = OrderedMeal.check_pace(time)
      # necessity_reschedule_for_cook_time = false
      if necessity_reschedule_for_cook_time || necessity_reschedule_for_ordered_meals || necessity_reschedule_for_visit_time
        Schedule.rescheduling(time, necessity_reschedule_for_visit_time, necessity_reschedule_for_cook_time, necessity_reschedule_for_ordered_meals)
      end

      end_time = (Schedule.maximum(:end_time) + 600).round
      time += 60
      i += 1
    end
    time_satisfaction = OrderedMeal.time_satisfaction
    wort_time_balance = Chef.work_time_balance
    Evaluate.create(time_satisfaction: time_satisfaction, wort_time_balance: wort_time_balance)
    ProcessTime.first.update(now: end_time.round)
    # redirect_to root_path
  end

  def show
    @time = ProcessTime.now.round
    @chefs = Chef.all 
  end

  def next_time
    next_time = (ProcessTime.now + 60).round
    ProcessTime.first.update(now: next_time)
  
    necessity_reschedule_for_cook_time = Schedule.every_process(next_time)
    necessity_reschedule_for_ordered_meals = OrderedMeal.check_pace(next_time)
    if necessity_reschedule_for_cook_time || necessity_reschedule_for_ordered_meals
      Schedule.rescheduling(next_time, necessity_reschedule_for_cook_time, necessity_reschedule_for_ordered_meals)
    end
    redirect_to moment_path
  end

  def reset_all
    Customer.all.destroy_all
    Chef.reset_work_time
    Customer.create_samples
    ordered_meal_ids = OrderedMeal.all.pluck(:id)
    Schedule.backward_scheduling(nil, false, ordered_meal_ids)
    ProcessTime.set_zero_time
    # redirect_to root_path
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

  def repetition
    repetition_count = 10

    for i in 1..repetition_count do
      reset_all
      active
    end
  end

end
