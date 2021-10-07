class Schedule < ApplicationRecord
  belongs_to :ordered_meal
  belongs_to :cook
  belongs_to :chef

  def time_change_ary(chart_start_time)
    start_mark = ((start_time - chart_start_time) / 60).round
    end_mark = ((end_time - chart_start_time) / 60).round

    return start_mark, end_mark
  end

  def self.every_process(time)
    start_cook(time)
    end_cook(time)
  end

  def self.start_cook(time)
    schedules = Schedule.where(start_time: time, is_rescheduled: false)
    schedules.each do |schedule|
      unless schedule.ordered_meal.is_started
        schedule.ordered_meal.update(is_started: true)
      end
    end
  end

  def self.end_cook(time)
    schedules = Schedule.where(end_time: time, is_rescheduled: false)
    schedules.each do |schedule|
      if schedule.cook.is_last
        schedule.ordered_meal.update(actual_served_time: time)
      end
    end
  end

  def self.rescheduling(time)
    margin_time = 5
    recent_orderd_meal_ids = []
    recent_schedules = Schedule.where(start_time: time..(time + margin_time * 60)).includes(:cook)

    if recent_schedules.present?
      recent_schedules.each do |schedule|
        if schedule.cook.permutation == 1
          recent_orderd_meal_ids << schedule.ordered_meal_id
        end
      end
    end

    recent_orderd_meals = OrderedMeal.where(id: [recent_orderd_meal_ids])
    recent_orderd_meals.each do |recent_ordered_meal|
      ordered_meal = OrderedMeal.find_by(customer_id: recent_ordered_meal.customer_id, meal_id: recent_ordered_meal.meal_id, is_rescheduled: false)
      recent_ordered_meal.schedules.each do |schedule|
        schedule.update(ordered_meal_id: ordered_meal.id) 
      end
      recent_orderd_meal_ids << ordered_meal.id
    end
    
    ordered_meal_ids = OrderedMeal.where(is_started: false).pluck(:id) - recent_orderd_meal_ids
    backward_scheduling(time, true, ordered_meal_ids)
  end

  def self.staging_reschedule(ordered_meal_ids)
    schedules = Schedule.where(ordered_meal_id: [ordered_meal_ids])
    schedules.each do |schedule|
      unless schedule.is_rescheduled
        schedule.update(is_rescheduled: true)
        removed_time = schedule.chef.work_time - (schedule.end_time - schedule.start_time).round
        schedule.chef.update(work_time: removed_time)
      end
    end
  end

  def self.backward_scheduling(time, is_rescheduling, ordered_meal_ids, time_diff=0)
    
    staging_reschedule(ordered_meal_ids)
   
    customers = Customer.all
    staging_cooks = []
    ordered_meals = OrderedMeal.where(id: [ordered_meal_ids], is_rescheduled: false)

    customers.each do |customer|
      if ordered_meals.where(customer_id: customer.id).exists?
        #[[調理終了時間, 調理工程, 注文料理id], ....]
        ordered_meal = ordered_meals.where(customer_id: customer.id).last
        staging_cooks << [ordered_meal.ideal_served_time + time_diff, ordered_meal.meal.cooks.last, ordered_meal.id]
      end
    end

    max_time_diff = 0
    while staging_cooks.length != 0 do
      end_time = staging_cooks.max[0]
      cook = staging_cooks.max[1]
      ordered_meal_id = staging_cooks.max[2]

      start_time = end_time - cook.time * 60

      chef, @ajusted_end_time = Chef.search(start_time, end_time, cook.skill, cook.is_free, ordered_meal_ids)
      @ajusted_start_time = @ajusted_end_time - (cook.time * chef.cook_speed).round * 60
      
      unless cook.is_free
        overlap_time = check_overlaps(chef, @ajusted_start_time,@ajusted_start_time, ordered_meal_ids)
        if overlap_time.present? && overlap_time > 0
          # byebug
          @ajusted_start_time += overlap_time
          @ajusted_end_time += overlap_time
          time_shift(ordered_meal_ids, overlap_time)
        end
      end
      
      reschedule_time = time if is_rescheduling

      new_schedule = Schedule.new(chef_id: chef.id, cook_id: cook.id, ordered_meal_id: ordered_meal_id, start_time: @ajusted_start_time, end_time: @ajusted_end_time, is_free: cook.is_free, reschedule_time: reschedule_time, is_rescheduled: false)  
      if new_schedule.save!
        work_time = chef.work_time + (@ajusted_end_time - @ajusted_start_time).round
        chef.update(work_time: work_time)
      end


      if is_rescheduling && new_schedule.start_time < time
        tmp_time_diff = (time - new_schedule.start_time)
        if max_time_diff < tmp_time_diff
          max_time_diff = tmp_time_diff
        end
      end
      

      next_cook = Cook.find_by(id: cook.id - 1)
      if next_cook.present? && ordered_meals.where(customer_id: new_schedule.ordered_meal.customer_id, meal_id: next_cook.meal.id).blank?
        next_cook = nil
      end

      index = staging_cooks.each_with_index.max[1]
      if next_cook.present?
        if next_cook.rear_cooks.present?
          rear_cook_schedule = Schedule.find_by(cook_id: next_cook.rear_cooks.first.id, ordered_meal_id: ordered_meal_id)
          staging_cooks[index][0] = rear_cook_schedule.start_time
        elsif cook.meal.id != next_cook.meal.id
          ordered_meal = ordered_meals.where(customer_id: new_schedule.ordered_meal.customer_id, id: 0...new_schedule.ordered_meal.id).last
          staging_cooks[index][0] = [ordered_meal.ideal_served_time, @ajusted_start_time].min
          staging_cooks[index][2] = ordered_meal.id
        else
          staging_cooks[index][0] = @ajusted_start_time
        end
        staging_cooks[index][1] = next_cook
      else
        staging_cooks.delete_at(index)
      end
    end

    if max_time_diff != 0
      time_shift(ordered_meal_ids, max_time_diff)
    end
  end

  def self.check_overlaps(chef, start_time, schedule_end_time, ordered_meal_ids)
    end_time = chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).minimum(:start_time)
    if end_time.blank?
    end_time = schedule_end_time
    end
    overlaps = chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', start_time, end_time)
    if overlaps.present?
      @overlap_time = 0
      overlaps.each do |schedule|
        tmp_overlap_time = schedule.end_time - start_time
        if @overlap_time < tmp_overlap_time
          @overlap_time = tmp_overlap_time
        end
      end
    end

    # if @overlap_time.present?
    #   byebug
    # end

    return @overlap_time
  end


  def self.time_shift(ordered_meal_ids, shift_time)
    update_data = Schedule.where(ordered_meal_id: [ordered_meal_ids], is_rescheduled: false)
    update_data.each do |schedule|
      start_time = schedule.start_time + shift_time
      end_time = schedule.end_time + shift_time
      schedule.update(start_time: start_time, end_time: end_time)
    end
  end

end
