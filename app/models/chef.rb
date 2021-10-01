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

  def self.search(start_time, end_time, skill, is_free, ordered_meal_ids)
    chefs = self.where(skill: skill.to_i..3).sort{|a, b| a.skill <=> b.skill}
    @end_time = end_time

    if is_free
      @chef = chefs.first
    else
      chefs.each do |chef|
        if chef.schedules.where(is_free: false, is_rescheduled: false).where('end_time > ? and ? > start_time', start_time, end_time).exists?
          if @end_time == end_time || @end_time < chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).minimum(:start_time)
            @end_time = chef.schedules.where(is_free: false, is_rescheduled: false, ordered_meal_id: [ordered_meal_ids]).minimum(:start_time)
            @chef = chef
          end
        else
          @chef = chef
          @end_time = end_time
          break
        end
      end
    end

    return @chef, @end_time
  end
end
