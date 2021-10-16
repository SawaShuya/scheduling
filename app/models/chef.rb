class Chef < ApplicationRecord
  has_many :schedules

  def cook_speed
    if skill == 1
      speed = 1.1
    elsif skill == 2
      speed = 1.0
    elsif skill == 3
      speed = 0.9
    end
    return speed
  end

  def self.reset_work_time
    Chef.all.each do |chef|
      chef.update(work_time: 0)
    end
  end

  def self.search(start_time, end_time, skill, is_free, ordered_meal_ids)
    # chefs = self.where(skill: skill.to_i..3).sort{|a, b| a.skill <=> b.skill}
    chefs = self.where(skill: skill.to_i..3).sort{|a, b| a.work_time <=> b.work_time}
    @end_time = end_time
    cook_time = end_time - start_time
    is_overlapped = false
    @chef = nil

    if is_free
      @chef = chefs.first
    else
      chefs.each do |chef|
        
        # if chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', start_time, end_time).exists? && chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).exists?
        if chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', start_time, end_time).exists?
          min_end_time = chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).minimum(:start_time)
          if min_end_time.present? && min_end_time < end_time
            min_start_time = (min_end_time - cook_time).round

            if chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', min_start_time, min_end_time).blank? && (@end_time == end_time || @end_time < min_end_time)
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
      # byebug
      chefs.each do |chef|
        min_end_time = chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).minimum(:start_time)
        if min_end_time.present? && end_time > min_end_time && (@end_time == end_time || @end_time < min_end_time)
          @end_time = min_end_time
          @chef = chef
        end
      end
      if @chef.blank?
        @chef = chefs.first
        @end_time = @chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).minimum(:start_time) || end_time
      end
      is_overlapped = true
    end

    return @chef, @end_time, is_overlapped
  end
end
