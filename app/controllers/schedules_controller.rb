class SchedulesController < ApplicationController
  

  def index
    @chefs = Chef.all
    @customers = Customer.all.includes(:style).sort{|a, b| a.reserved_time <=> b.reserved_time}
    @time_satisfaction = OrderedMeal.time_satisfaction
  end

  def active
    time = Schedule.minimum(:start_time)
    end_time = Schedule.maximum(:end_time)
    while time <= end_time do
      Schedule.every_process(time)
      OrderedMeal.check_pace(time)
      end_time = Schedule.maximum(:end_time)
      time += 60
    end
    redirect_to root_path
  end

end
