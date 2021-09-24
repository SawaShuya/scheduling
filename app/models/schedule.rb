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
    schedules = Schedule.where(start_time: time)
    schedules.each do |schedule|
      unless schedule.ordered_meal.is_started
        schedule.ordered_meal.update(is_started: true)
      end
    end
  end

  def self.end_cook(time)
    schedules = Schedule.where(end_time: time)
    schedules.each do |schedule|
      if schedule.cook.is_last
        schedule.ordered_meal.update(actual_served_time: time)
      end
    end
  end

end
