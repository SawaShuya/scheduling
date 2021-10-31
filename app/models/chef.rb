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

  def self.wort_time_balance
    0
  end

  def has_overlaps?(start_time, end_time)
    self.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', start_time, end_time).exists?
  end

  def rescheduled_schedules(ordered_meal_ids)
    self.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids])
  end

  def self.search(start_time, end_time, skill, is_free, ordered_meal_ids)
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
        if chef.has_overlaps?(start_time, end_time)
          min_end_time = chef.rescheduled_schedules(ordered_meal_ids).minimum(:start_time)
          if min_end_time.present? && min_end_time < end_time
            min_start_time = (min_end_time - cook_time).round
            if !chef.has_overlaps?(min_start_time, min_end_time) && (@end_time == end_time || @end_time < min_end_time)
              @end_time = min_end_time
              @chef = chef
            end
          elsif min_end_time.present? && end_time > min_end_time && (@tmp_end_time == end_time || @tmp_end_time < min_end_time)
            @tmp_end_time = min_end_time
            @tmp_chef = chef
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
      if @tmp_chef.present?
        @end_time = @tmp_end_time
        @chef = @tmp_chef
      else
        @chef = chefs.first
        @end_time = @chef.rescheduled_schedules(ordered_meal_ids).minimum(:start_time) || end_time
      end
    end

    return @chef, @end_time, is_overlapped
  end
end
