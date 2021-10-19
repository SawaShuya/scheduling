class Schedule < ApplicationRecord
  belongs_to :ordered_meal
  belongs_to :cook
  belongs_to :chef


  def time_change_ary(chart_start_time)
    start_mark = ((start_time - chart_start_time) / 60).round
    end_mark = ((end_time - chart_start_time) / 60).round

    return start_mark, end_mark
  end

  def is_finished?
    self.actual_end_time.present?
  end

  def ahead_cooks_finished?
    ahead_cooks = self.chef.schedules.where(is_rescheduled: false, ordered_meal_id: self.ordered_meal_id, cook_id: self.cook.ahead_cooks.pluck(:id))
    ahead_cooks.where(actual_end_time: nil).exists?
  end

  def last_ahead_cook
    ahead_cooks = self.chef.schedules.where(is_rescheduled: false, ordered_meal_id: self.ordered_meal_id, cook_id: self.cook.ahead_cooks.pluck(:id))
    ahead_cook = ahead_cooks.sort{|a, b| a.actual_end_time <=> b.actual_end_time}.last
    return ahead_cook
  end

  def actual_cook_time
    (self.cook.time * self.actual_velocity_params).round
  end

  def self.every_process(time)
    end_cook(time)
    start_cook(time)
  end

  def self.start_cook(time)
    schedules = Schedule.where(is_rescheduled: false, actual_start_time: nil).where('start_time <= ?', time.round)
    schedules.each do |schedule|
      chef = schedule.chef
      last_schedule = chef.schedules.where(is_rescheduled: false, is_free: false).where('start_time < ?', schedule.start_time.round).sort{|a, b| a.start_time <=> b.start_time}.last
      if schedule.cook.ahead_cooks.present? && schedule.ahead_cooks_finished? && (last_schedule.nil? || !last_schedule.is_finished? || last_schedule.actual_end_time < schedule.last_ahead_cook.actual_end_time)
        last_schedule = schedule.last_ahead_cook
      end

      if schedule.is_free || last_schedule.nil? || last_schedule.is_finished?
        schedule.update(actual_start_time: time.round)
        if schedule.cook.permutation == 1
          schedule.ordered_meal.update(is_started: true)
        end
      end
    end
  end

  def self.end_cook(time)
    schedules = Schedule.where(is_rescheduled: false, actual_end_time: nil).where.not(actual_start_time: nil)
    schedules.each do |schedule|
      if (schedule.actual_start_time + schedule.actual_cook_time * 60).round <= time.round
        schedule.update(actual_end_time: time.round)
        if schedule.cook.is_last
          schedule.ordered_meal.update(actual_served_time: time.round)
        end
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

    replace_orderd_meals = OrderedMeal.where(id: [recent_orderd_meal_ids]).or(OrderedMeal.where(is_started: true, actual_served_time: nil, is_rescheduled: true))
    replace_orderd_meals.each do |replace_ordered_meal|
      ordered_meal = OrderedMeal.find_by(customer_id: replace_ordered_meal.customer_id, meal_id: replace_ordered_meal.meal_id, is_rescheduled: false)
      replace_ordered_meal.schedules.where(is_rescheduled: false).each do |schedule|
        new_schedule_params = schedule.attributes.reject{|key, value| key == "id" || key == "created_at" || key == "updated_at" || key == "ordered_meal_id" || key == "is_rescheduled"}
        new_schedule_params.merge!({ordered_meal_id: ordered_meal.id, reschedule_time: time.round, is_rescheduled: false})
        Schedule.create!(new_schedule_params)
        schedule.update(is_rescheduled: true) 
      end
      if recent_orderd_meal_ids.include?(replace_ordered_meal.id)
        recent_orderd_meal_ids << ordered_meal.id
      end
    end
    
    ordered_meal_ids = OrderedMeal.where(is_started: false).pluck(:id) - recent_orderd_meal_ids
    backward_scheduling(time, true, ordered_meal_ids)
  end

  def self.staging_reschedule(ordered_meal_ids)
    schedules = Schedule.where(ordered_meal_id: [ordered_meal_ids], is_rescheduled: false)
    schedules.each do |schedule|
      unless schedule.is_rescheduled
        schedule.update(is_rescheduled: true)
        removed_time = schedule.chef.work_time - (schedule.end_time - schedule.start_time).round
        schedule.chef.update(work_time: removed_time)
      end
    end
  end

  def self.backward_scheduling(time, is_rescheduling, ordered_meal_ids)
    
    staging_reschedule(ordered_meal_ids)
   
    customers = Customer.all
    staging_cooks = []
    ordered_meals = OrderedMeal.where(id: [ordered_meal_ids], is_rescheduled: false)

    customers.each do |customer|
      if ordered_meals.where(customer_id: customer.id).exists?
        #[[調理終了時間, 調理工程, 注文料理id], ....]
        ordered_meal = ordered_meals.where(customer_id: customer.id).last
        staging_cooks << [ordered_meal.ideal_served_time, ordered_meal.meal.cooks.last, ordered_meal.id]
      end
    end

    max_time_diff = 0
    while staging_cooks.length != 0 do
      end_time = staging_cooks.max[0]
      cook = staging_cooks.max[1]
      ordered_meal_id = staging_cooks.max[2]

      start_time = end_time - cook.time * 60

      chef, @ajusted_end_time, is_overlapped = Chef.search(start_time.round, end_time.round, cook.skill, cook.is_free, ordered_meal_ids)
      @ajusted_start_time = @ajusted_end_time - (cook.time * chef.cook_speed).round * 60
      # @ajusted_start_time = @ajusted_end_time - cook.time.round * 60
      
      reschedule_time = time if is_rescheduling

      new_schedule = Schedule.new(chef_id: chef.id, cook_id: cook.id, ordered_meal_id: ordered_meal_id, start_time: @ajusted_start_time.round, end_time: @ajusted_end_time.round, is_free: cook.is_free, reschedule_time: reschedule_time, is_rescheduled: false, actual_velocity_params: chef.actual_cook_speed)
      if new_schedule.save!
        work_time = chef.work_time + (@ajusted_end_time - @ajusted_start_time).round
        chef.update(work_time: work_time)
      end

      if is_overlapped
        forward_scheduling(new_schedule, ordered_meal_ids)
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
        else
          ordered_meal = OrderedMeal.where(customer_id: new_schedule.ordered_meal.customer_id, id: 0...new_schedule.ordered_meal.id, is_rescheduled: false, is_started: false).last
          staging_cooks[index][0] = [ordered_meal.ideal_served_time, @ajusted_start_time].min
          staging_cooks[index][2] = ordered_meal.id
        end
        staging_cooks[index][1] = next_cook
      else
        staging_cooks.delete_at(index)
      end
    end

    # if max_time_diff != 0
    #   time_shift(ordered_meal_ids, max_time_diff)
    # end
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

  def self.forward_scheduling(new_schedule, ordered_meal_ids)
    staging_schedule = [new_schedule]
    chef_schedule = []
    chef = new_schedule.chef
    chefs = Chef.all
    chefs.each_with_index do |chef|
      chef_schedule << chef.schedules.where(is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).sort{|a, b| a.start_time <=> b.start_time}.pluck(:id)
      # chef_schedule << chef.schedules.where(is_rescheduled: false, is_free: false).where('start_time > ?', new_schedule.start_time).sort{|a, b| a.start_time <=> b.start_time}.pluck(:id)
      # if chef == new_schedule.chef
      #   chef_schedule[chef.id - 1].unshift(new_schedule.id)
      # end
    end

    while staging_schedule.length != 0 do
      schedule = staging_schedule[0]
      chef = schedule.chef
      last_end_time = nil

      overlap_schedules = chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', schedule.start_time.round, schedule.end_time.round).where.not(id: schedule.id)
      if !schedule.is_free && overlap_schedules.exists? && (last_end_time.blank? || last_end_time < overlap_schedules.maximum(:end_time))
        last_end_time = overlap_schedules.maximum(:end_time)
      end

      if schedule.cook.ahead_cooks.present?
        last_schedules = Schedule.where(is_rescheduled: false, ordered_meal_id: schedule.ordered_meal_id ,cook_id: schedule.cook.ahead_cooks.pluck(:id))
        if last_schedules.present? && schedule.start_time < last_schedules.maximum(:end_time) && (last_end_time.blank? || last_end_time < last_schedules.maximum(:end_time))
          last_end_time = last_schedules.maximum(:end_time)
        end
      end

      if last_end_time.present? && last_end_time > schedule.start_time
        overlap_time = last_end_time - schedule.start_time
        ajust_start_time = schedule.start_time + overlap_time
        ajust_end_time = schedule.end_time + overlap_time
        if !schedule.is_free && chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', ajust_start_time.round, ajust_end_time.round).where.not(ordered_meal_id: [ordered_meal_ids]).exists?
          last_end_time = chef.schedules.where(is_free: false, is_rescheduled: false).where.not(ordered_meal_id: [ordered_meal_ids]).maximum(:end_time)
          overlap_time = last_end_time - schedule.start_time
          ajust_start_time = schedule.start_time + overlap_time
          ajust_end_time = schedule.end_time + overlap_time
          if chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', ajust_start_time.round, ajust_end_time.round).where.not(id: schedule.id).exists?
            last_end_time = chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', ajust_start_time.round, ajust_end_time.round).where.not(id: schedule.id).maximum(:end_time)
            overlap_time = last_end_time - schedule.start_time
            ajust_start_time = schedule.start_time + overlap_time
            ajust_end_time = schedule.end_time + overlap_time
          end
        end

        schedule.update(start_time: ajust_start_time.round, end_time: ajust_end_time.round)
      

        schedule_index = chef_schedule[chef.id - 1].index(schedule.id)
        if schedule_index.present? && chef_schedule[chef.id - 1][schedule_index + 1].present?
          staging_schedule << Schedule.find(chef_schedule[chef.id - 1][schedule_index + 1])
        end

        if schedule.cook.rear_cooks.present?
          staging_schedule << Schedule.find_by(is_rescheduled: false, ordered_meal_id: schedule.ordered_meal_id, cook_id: schedule.cook.rear_cooks.first.id)
        end
      elsif schedule.is_free
        schedule_index = chef_schedule[chef.id - 1].index(schedule.id)
        if schedule_index.present? && chef_schedule[chef.id - 1][schedule_index + 1].present?
          staging_schedule << Schedule.find(chef_schedule[chef.id - 1][schedule_index + 1])
        end
      end

      staging_schedule.shift
      staging_schedule.sort!{|a, b| a.start_time <=> b.start_time}
      staging_schedule.uniq!
    end
  end

end
