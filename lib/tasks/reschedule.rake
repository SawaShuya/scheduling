namespace :reschedule do

  desc '動的スケジュール'
  task :start => :environment do
    time = ProcessTime.now
    end_time = Schedule.maximum(:end_time)
    while time <= end_time do
      puts time
      Schedule.every_process(time)
      OrderedMeal.check_pace(time)
      end_time = Schedule.maximum(:end_time)
      time += 60

    end
    ProcessTime.first.update(now: end_time)
  end

  desc '繰り返し'
  task :repitation => :environment do
    SchedulesController.new.repetition
  end
end
