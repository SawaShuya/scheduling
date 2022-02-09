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
    ahead_cooks.where(actual_end_time: nil).blank?
  end

  def last_ahead_cook
    ahead_cooks = Schedule.where(is_rescheduled: false, ordered_meal_id: self.ordered_meal_id, cook_id: self.cook.ahead_cooks.pluck(:id))
    if ahead_cooks.where(actual_end_time: nil).present?
      ahead_cook = ahead_cooks.where(actual_end_time: nil).sort{|a, b| a.end_time <=> b.end_time}.last
    else
      ahead_cook = ahead_cooks.sort{|a, b| a.actual_end_time <=> b.actual_end_time}.last
    end
    
    return ahead_cook
  end

  def self.check_startable(schedule, last_schedule, last_ahead_schedule)
    is_startable = false
    
    if schedule.is_free
      if (last_ahead_schedule && last_ahead_schedule.is_finished?) || !last_ahead_schedule
        is_startable = true
      end
    else
      if (last_schedule && last_ahead_schedule && last_schedule.is_finished? && last_ahead_schedule.is_finished?) || (!last_schedule && last_ahead_schedule && last_ahead_schedule.is_finished?) || (last_schedule && !last_ahead_schedule && last_schedule.is_finished?) || (!last_schedule && !last_ahead_schedule)
        is_startable = true
      end
    end

    return is_startable

  end

  def actual_cook_time
    (self.cook.time * self.actual_velocity_params).round
  end

  def self.every_process(time)
    is_necessity = end_cook(time)
    start_cook(time)
    return is_necessity
  end

  def self.start_cook(time)
    schedules = Schedule.where(is_rescheduled: false, actual_start_time: nil).where('start_time <= ?', time.round)
    schedules.each do |schedule|
      chef = schedule.chef

      last_schedule = chef.schedules.where(is_rescheduled: false, is_free: false).where('start_time <= ?', schedule.start_time.round).where.not(id: schedule.id).sort{|a, b| a.start_time <=> b.start_time}.last
      last_ahead_cook_schedule = schedule.last_ahead_cook if schedule.cook.ahead_cooks.present?

      is_startable = check_startable(schedule, last_schedule, last_ahead_cook_schedule)

      if is_startable && schedule.ordered_meal.customer.is_visited?(time)
        schedule.update(actual_start_time: time.round)
        if !schedule.ordered_meal.is_started
          schedule.ordered_meal.update(is_started: true)
        end
      end
    end
  end

  def self.end_cook(time)
    is_necessity = false
    limit_overlap_time = 0
    schedules = Schedule.where(is_rescheduled: false, actual_end_time: nil).where.not(actual_start_time: nil)
    schedules.each do |schedule|
      if (schedule.actual_start_time + schedule.actual_cook_time * 60).round <= time.round
        schedule.update(actual_end_time: time.round)
        if schedule.cook.is_last
          schedule.ordered_meal.update(actual_served_time: time.round)
        end
        if (time - schedule.end_time) > limit_overlap_time
          is_necessity = true
        end
      end
    end  
    return is_necessity
  end

  def self.rescheduling(time, necessity_reschedule_for_visit_time, necessity_reschedule_for_cook_time, necessity_reschedule_for_ordered_meals)
    ordered_meal_ids, started_schedule_ids = nil, nil

    if necessity_reschedule_for_visit_time || necessity_reschedule_for_cook_time || necessity_reschedule_for_ordered_meals
      ordered_meal_ids, started_schedule_ids = set_reschedule_ordered_meals(time, necessity_reschedule_for_visit_time, necessity_reschedule_for_cook_time, necessity_reschedule_for_ordered_meals)
    end

    staging_reschedule(ordered_meal_ids, started_schedule_ids)

    backward_scheduling(time, true, ordered_meal_ids)
  end

  def self.set_reschedule_ordered_meals(time, necessity_reschedule_for_visit_time, necessity_reschedule_for_cook_time, necessity_reschedule_for_ordered_meals)
    ordered_meal_ids = []
    started_schedule_ids =[]

    ordered_meal_ids.concat OrderedMeal.where(is_rescheduled: false, is_started: false).pluck(:id)

    if necessity_reschedule_for_cook_time
      started_schedule_ids.concat ajust_started_schedules(time)
    end
    
    if necessity_reschedule_for_visit_time
      started_orderd_meals = OrderedMeal.where(is_rescheduled: false, is_started: true, actual_served_time: nil)
      started_orderd_meals.each do |started_ordered_meal|
        started_schedule_ids.concat started_ordered_meal.schedules.where(is_rescheduled: false, actual_end_time: nil).pluck(:id)
      end
    end

    if necessity_reschedule_for_ordered_meals
      set_rescheduled_started_ordered_meals(time)



      started_orderd_meals = OrderedMeal.where(is_rescheduled: false, is_started: true, actual_served_time: nil)
      started_orderd_meals.each do |started_ordered_meal|
        started_schedule_ids.concat started_ordered_meal.schedules.where(is_rescheduled: false, actual_end_time: nil).pluck(:id)
      end
    end

    return ordered_meal_ids.compact.uniq, started_schedule_ids.compact.uniq
  end

  def self.ajust_started_schedules(time)
    chefs = Chef.all
    chef_schedules = []
    staging_schedules = []
    started_schedule_ids = []
    started_ordered_meal_ids = OrderedMeal.where(is_rescheduled: false, is_started: true, actual_served_time: nil).pluck(:id)
    schedules = Schedule.where(is_rescheduled: false, ordered_meal_id: started_ordered_meal_ids)
    
    started_orderd_meals = OrderedMeal.where(is_rescheduled: false, is_started: true, actual_served_time: nil)
    started_orderd_meals.each do |started_ordered_meal|
      started_schedule_ids.concat started_ordered_meal.schedules.where(is_rescheduled: false, actual_end_time: nil).sort{|a, b| a.start_time <=> b.start_time}.pluck(:id)
    end
    chefs.each do |chef|
      chef_schedules << chef.schedules.where(is_rescheduled:false, ordered_meal_id: started_ordered_meal_ids).sort{|a, b| a.start_time <=> b.start_time}.pluck(:id)
    end

    delay_schedules = Schedule.where(is_rescheduled: false, ordered_meal_id: started_ordered_meal_ids, actual_start_time: time.round).where('start_time < ?', time.round)
    delay_schedules.each do |delay_schedule|
      delay = delay_schedule.actual_start_time - delay_schedule.start_time
      new_schedule_params = delay_schedule.attributes.reject{|key, value| key == "id" || key == "created_at" || key == "updated_at"}
      new_schedule_params.merge!({start_time: (delay_schedule.start_time + delay).round, end_time: (delay_schedule.end_time + delay).round,reschedule_time: time.round, is_rescheduled: false})
      new_schedule = Schedule.new(new_schedule_params)
      new_schedule.save!
      delay_schedule.update(is_rescheduled: true)
      started_schedule_ids << new_schedule.id
      
      delay_schedule_index = chef_schedules[delay_schedule.chef_id - 1].index(delay_schedule.id)
      chef_schedules[delay_schedule.chef_id - 1][delay_schedule_index] = new_schedule.id

      next_staging_schedules = set_next_staging_schedules(chef_schedules, delay_schedule)
      staging_schedules.concat next_staging_schedules
    end

    staging_schedules.sort!{|a, b| a.start_time <=> b.start_time}

    while staging_schedules.length != 0 do
      schedule = staging_schedules[0]
      limit_time = []
      index = chef_schedules[schedule.chef_id - 1].index(schedule.id)
      i = 0
      i += 1

      if i >= 100
        puts "ajust_cook error"
        p staging_schedule.map{|a| [a.id, a.ordered_meal_id, a.cook_id, a.chef_id, a.start_time]}
        if i >= 115
          byebug
        end
      end

      if !schedule.is_free
        if index.nil?
          byebug
        end
        i = 1

        loop do
          last_schedule = Schedule.find_by(id: chef_schedules[schedule.chef_id - 1][index - i])
          if last_schedule.present? && !last_schedule.is_free
            limit_time << last_schedule.end_time
            break
          end
          if last_schedule.nil?
            break
          end
          i += 1
        end
      end

      if schedule.cook.ahead_cooks.present?
        # byebug
        last_ahead_schedule = Schedule.where(is_rescheduled: false, ordered_meal_id: schedule.ordered_meal_id, cook_id: schedule.cook.ahead_cooks.pluck(:id)).sort{|a, b| a.end_time <=> b.end_time}.last
        if last_ahead_schedule.present?
          limit_time << last_ahead_schedule.end_time
        end
      end 
      
      max_limit_time = limit_time.max
      if max_limit_time.present? && max_limit_time > schedule.start_time
        new_schedule_params = schedule.attributes.reject{|key, value| key == "id" || key == "created_at" || key == "updated_at"}
        new_schedule_params.merge!({start_time: max_limit_time.round, end_time: (schedule.end_time + (max_limit_time - schedule.start_time)).round, reschedule_time: time.round, is_rescheduled: false})
        new_schedule = Schedule.new(new_schedule_params)
        new_schedule.save!
        schedule.update(is_rescheduled: true)
        started_schedule_ids << new_schedule.id

        next_staging_schedules = set_next_staging_schedules(chef_schedules, schedule)
        staging_schedules.concat next_staging_schedules

        if started_schedule_ids.include?(schedule.id)
          started_schedule_ids.delete(schedule.id)
        end

        chef_schedules[schedule.chef_id - 1][index] = new_schedule.id
      end
      staging_schedules.shift
      staging_schedules.sort!{|a, b| [a.start_time, - a.id] <=> [b.start_time, - b.id]}
      staging_schedules.uniq!
    end

    return started_schedule_ids.compact

  end

  def self.set_rescheduled_started_ordered_meals(time)
    rescheduled_started_ordered_meals = OrderedMeal.where(is_rescheduled: true, reschedule_time: time.round, is_started: true)

    rescheduled_started_ordered_meals.each do |rescheduled_ordered_meal|
      replaced_ordered_meal = OrderedMeal.find_by(is_rescheduled: false, meal_id: rescheduled_ordered_meal.meal_id, customer_id: rescheduled_ordered_meal.customer_id)
      rescheduled_ordered_meal.schedules.where(is_rescheduled: false).each do |schedule|
        new_schedule_params = schedule.attributes.reject{|key, value| key == "id" || key == "created_at" || key == "updated_at" || key == "ordered_meal_id"}
        new_schedule_params.merge!({ordered_meal_id: replaced_ordered_meal.id, reschedule_time: time.round})
        started_schedule = Schedule.new(new_schedule_params)
        started_schedule.save!
        schedule.update!(is_rescheduled: true)
      end
    end
  end

  def self.staging_reschedule(ordered_meal_ids, started_schedule_ids)
    rescheduled_schedules = Schedule.where(is_rescheduled: false, actual_end_time: nil).where.not(id: started_schedule_ids)

    rescheduled_schedules.each do |schedule|
      schedule.update(is_rescheduled: true)
      removed_time = schedule.chef.work_time - (schedule.end_time - schedule.start_time).round
      schedule.chef.update(work_time: removed_time)
    end
  end

  def self.backward_scheduling(time, is_rescheduling, ordered_meal_ids)
    customers = Customer.all
    staging_cooks = []
    ordered_meals = OrderedMeal.where(id: [ordered_meal_ids], is_rescheduled: false)
    start_schedule_id = Schedule.maximum(:id) + 1 if is_rescheduling

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

      chef, @ajusted_end_time, is_overlapped = Chef.search(time, start_time.round, end_time.round, cook.skill, cook.is_free, ordered_meal_ids)
      # @ajusted_start_time = @ajusted_end_time - (cook.time * chef.cook_speed).round * 60
      @ajusted_start_time = @ajusted_end_time - cook.time.round * 60
      
      reschedule_time = time if is_rescheduling

      new_schedule = Schedule.new(chef_id: chef.id, cook_id: cook.id, ordered_meal_id: ordered_meal_id, start_time: @ajusted_start_time.round, end_time: @ajusted_end_time.round, is_free: cook.is_free, reschedule_time: reschedule_time, is_rescheduled: false, actual_velocity_params: chef.actual_cook_speed)
      if new_schedule.save!
        work_time = chef.work_time + (@ajusted_end_time - @ajusted_start_time).round
        chef.update(work_time: work_time)
      end

      if is_overlapped
        forward_scheduling(time, new_schedule, ordered_meal_ids, start_schedule_id)
      end
      
      next_cook = set_next_cook(new_schedule)

      index = staging_cooks.each_with_index.max[1]
      if next_cook.present?
        if next_cook.rear_cooks.present?
          rear_cook_schedule = Schedule.find_by(is_rescheduled: false, cook_id: next_cook.rear_cooks.first.id, ordered_meal_id: ordered_meal_id)
          staging_cooks[index][0] = rear_cook_schedule.start_time
        else
          ordered_meal = OrderedMeal.where(customer_id: new_schedule.ordered_meal.customer_id, id: 0...new_schedule.ordered_meal.id, is_rescheduled: false, is_started: false).sort{|a,b| a.meal_id <=> b.meal_id}.last
          if ordered_meal.nil?
            byebug
          end
          staging_cooks[index][0] = [ordered_meal.ideal_served_time, new_schedule.start_time].min
          staging_cooks[index][2] = ordered_meal.id
        end
        staging_cooks[index][1] = next_cook
      else
        staging_cooks.delete_at(index)
      end
    end
  end

  def self.set_next_cook(new_schedule)
    next_cook = Cook.find_by(id: new_schedule.cook_id - 1)
    customer = new_schedule.ordered_meal.customer

    ordered_meal_ids = OrderedMeal.where(is_rescheduled: false, customer_id: customer.id).pluck(:id)

    while next_cook.present? do
      assigned_schedule = Schedule.where(is_rescheduled: false, cook_id: next_cook.id, ordered_meal_id: ordered_meal_ids).last
      if assigned_schedule.present?
        cook_id = next_cook.id - 1
        next_cook = Cook.find_by(id: cook_id)
      else
        break
      end
    end

    return next_cook
  end

  def search_not_assigned_schedule(customer)
    next_cook = nil
    schedules = customer.ordered_meals.schedules(is_rescheduled: false)
    if schedules.count != Cook.all.count
      not_assigned_schedule_ids = Cook.all.pluck(:id) - schedules.pluck(:cook_id)
      next_cook = Cook.find(not_assigned_schedule_ids.last)
    end
    return next_cook

  end

  def self.time_shift(ordered_meal_ids, shift_time)
    update_data = Schedule.where(ordered_meal_id: [ordered_meal_ids], is_rescheduled: false)
    update_data.each do |schedule|
      start_time = schedule.start_time + shift_time
      end_time = schedule.end_time + shift_time
      schedule.update(start_time: start_time, end_time: end_time)
    end
  end

  def self.forward_scheduling(time, new_schedule, ordered_meal_ids, start_schedule_id)
    i = 0
    staging_schedule = [new_schedule]
    chef_schedule = []
    chef = new_schedule.chef
    chefs = Chef.all
    chefs.each do |chef|
      # chef_schedule << chef.schedules.where(is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).sort{|a, b| [a.start_time, - a.id] <=> [b.start_time, - b.id]}.pluck(:id)
      chef_schedule << chef.schedules.where(is_rescheduled: false).sort{|a, b| [a.start_time, a.id] <=> [b.start_time, b.id]}.pluck(:id)
    end

    while staging_schedule.length != 0 do
      i+=1
      if i >= 100
        puts "error"
        p staging_schedule.map{|a| [a.id, a.ordered_meal_id, a.cook_id, a.chef_id, a.start_time]}
        if i >= 115
          byebug
        end
      end
      schedule = staging_schedule[0]

      limit_time = check_overlaps(time, chef_schedule, schedule, start_schedule_id)

      if limit_time >= schedule.start_time.round
        if limit_time == time
          limit_time += 60
        end
        overlap_time = limit_time - schedule.start_time
        ajust_start_time = schedule.start_time + overlap_time
        ajust_end_time = schedule.end_time + overlap_time
        schedule.update(start_time: ajust_start_time.round, end_time: ajust_end_time.round)

        next_staging_schedules = set_next_staging_schedules(chef_schedule, schedule)
        staging_schedule.concat next_staging_schedules
      end

      staging_schedule.shift
      staging_schedule.sort!{|a, b| [a.start_time, a.end_time, -a.id] <=> [b.start_time, b.end_time, -b.id]}
      staging_schedule.uniq!

    end
  end

  def self.check_overlaps(time, chef_schedule, schedule, start_schedule_id)
    limit_times = []
    limit_times << time.round
    last_schedule = nil

    schedule_index = chef_schedule[schedule.chef_id - 1].index(schedule.id)
    # if !schedule.is_free && schedule_index.present? && schedule_index != 0
    if !schedule.is_free && schedule_index.present?
      i = 1
      loop do 
        last_schedule = Schedule.find_by(id: chef_schedule[schedule.chef_id - 1][schedule_index - i])
        if !last_schedule.is_free || last_schedule.nil?
          break
        end
        # if last_schedule.nil?
        #   last_schedule = Schedule.where(is_rescheduled: false, is_free: false, chef_id: schedule.chef_id).where('id < ?', start_schedule_id).sort{|a, b| a.end_time <=> b.end_time}.last
        #   break
        # end
        i += 1
      end
    # elsif !schedule.is_free && schedule_index.present? && schedule_index == 0
    #   last_schedule = Schedule.where(is_rescheduled: false, is_free: false, chef_id: schedule.chef_id).where('id < ?', start_schedule_id).sort{|a, b| a.end_time <=> b.end_time}.last
    end

    if last_schedule.present?
      limit_times << last_schedule.end_time.round
    end

    if schedule.cook.ahead_cooks.present?
      ahead_schedules = Schedule.where(is_rescheduled: false, ordered_meal_id: schedule.ordered_meal_id ,cook_id: schedule.cook.ahead_cooks.pluck(:id))
      if ahead_schedules.present?
        limit_times << ahead_schedules.maximum(:end_time).round
      end
    end

    limit_time = limit_times.compact.max

    return limit_time 
  end

  def self.set_next_staging_schedules(chef_schedule, schedule)
    staging_schedules = []
    schedule_index = chef_schedule[schedule.chef_id - 1].index(schedule.id)

    if schedule_index.present? && chef_schedule[schedule.chef_id - 1][schedule_index + 1].present?
      i = 1
      loop do
        next_schedule = Schedule.find_by(id: chef_schedule[schedule.chef_id - 1][schedule_index + i])

        if next_schedule.present? && !next_schedule.is_free && !staging_schedules.include?(next_schedule)
          staging_schedules << next_schedule
          break
        end

        if next_schedule.nil?
          break
        end

        i += 1
      end
    end

    if schedule.cook.rear_cooks.present?
      rear_cook_schedule = Schedule.where(is_rescheduled: false, ordered_meal_id: schedule.ordered_meal_id, cook_id: schedule.cook.rear_cooks.first.id).last
      if rear_cook_schedule.present? && !staging_schedules.include?(rear_cook_schedule)
        staging_schedules << rear_cook_schedule
      end
    end

    return staging_schedules.compact
  end

  

end
