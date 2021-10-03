class SchedulesController < ApplicationController
  

  def index
    @chefs = Chef.all
    @customers = Customer.all.includes(:style).sort{|a, b| a.reserved_time <=> b.reserved_time}
    @time_satisfaction = OrderedMeal.time_satisfaction
  end

  def active
    time = ProcessTime.now
    end_time = Schedule.maximum(:end_time)
    while time <= end_time do
      Schedule.every_process(time)
      OrderedMeal.check_pace(time)
      end_time = Schedule.maximum(:end_time)
      time += 60
    end
    ProcessTime.first.update(now: end_time)
    redirect_to root_path
  end

  def show
    @time = ProcessTime.now
    @chefs = Chef.all
  end

  def next_time
    next_time = ProcessTime.now + 60
    ProcessTime.first.update(now: next_time)
    redirect_to moment_path
  end

end
