class Chef < ApplicationRecord
  has_many :schedules

  def cook_speed
    if skill == 1
      speed = 1.2
    elsif skill == 2
      speed = 1.1
    elsif skill == 3
      speed = 1.0
    end
    return speed
  end

  def actual_cook_speed
    random = rand(1..10)
    speed = 1.0
    if (skill == 1 && random >= 8) || (skill == 2 && random >= 9) || (skill == 3 && random == 10)
      speed = (1.2 + rand(-0.15...0.15)).round(1)
    end
    return speed
  end

  def self.reset_work_time
    Chef.all.each do |chef|
      chef.update(work_time: 0)
    end
  end

  def self.work_time_balance
    
    time = Schedule.where(is_rescheduled:false).minimum(:actual_start_time).round
    last_time = Schedule.where(is_rescheduled:false).maximum(:actual_end_time).round
    chef_number = Chef.all.last.id
    work_times = Array.new(chef_number, 0)
    while time != last_time do
      just_time_schedules = Schedule.where(is_rescheduled: false).where('actual_end_time > ? and ? > actual_start_time', time, time)
      if just_time_schedules.present?
        chef_ids = just_time_schedules.pluck(:chef_id).uniq.sort
        chef_ids.each do |chef_id|
          work_times[chef_id - 1] += 1
        end
      end
      time = (time + 60).round
    end
    work_times.compact!
    wort_time_balance = calculate_work_time_balance(work_times)
    return wort_time_balance 
  end

  def self.calculate_work_time_balance(work_times)
    sum = work_times.sum
    average = sum / work_times.length
    @difference_sum = 0

    work_times.each do |work_time|
      difference = (work_time - average).abs
      @difference_sum += difference
    end

    return @difference_sum
  end

  def has_overlaps?(time, start_time, end_time)
    (time.present? && start_time < time) || self.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', start_time.round, end_time.round).exists?
  end

  def rescheduled_schedules(ordered_meal_ids)
    self.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids])
  end

  def asigned_schedules
    self.schedules.where(is_rescheduled: false, is_free: false).where('rescheduled_time < ?', time.round).or(self.schedules.where(is_rescheduled: false, is_free: false, rescheduled_time: nil))
  end

  def self.search(time, start_time, end_time, skill, is_free, ordered_meal_ids)
    # chefs = self.where(skill: skill.to_i..3).sort{|a, b| a.skill <=> b.skill}
    chefs = self.where(skill: skill.to_i..3).sort{|a, b| a.work_time <=> b.work_time}
    @end_time, @tmp_end_time = end_time, end_time
    cook_time = end_time - start_time
    is_overlapped = false
    @chef, @tmp_chef = nil, nil

    if is_free
      @chef = chefs.first
    else
      chefs.each do |chef|
        if chef.has_overlaps?(time, start_time, end_time)
          min_end_time = chef.rescheduled_schedules(ordered_meal_ids).minimum(:start_time)
          if min_end_time.present? && min_end_time < end_time
            min_start_time = (min_end_time - cook_time).round
            if !chef.has_overlaps?(time, min_start_time, min_end_time) && (@end_time == end_time || @end_time < min_end_time)
              @end_time = min_end_time
              @chef = chef
            end
          end
        else
          @chef = chef
          @end_time = end_time
          break
        end
      end
    end

    if @chef.blank?
      is_overlapped = true
      @chef = chefs.first
      @end_time = [@chef.rescheduled_schedules(ordered_meal_ids).minimum(:start_time), end_time].min
    end

    return @chef, @end_time, is_overlapped
  end
end
