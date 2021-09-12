namespace :scheduling do
  desc "予約のみスケジューリング"
  task :create => :environment do
    Schedule.all.destroy_all
    ordered_meals = OrderedMeal.all.includes(meal: :cooks).sort{|a, b| b.ideal_served_time <=> a.ideal_served_time}

    ordered_meals.each do |ordered_meal|
      cooks = ordered_meal.meal.cooks.sort{|a, b| b.id <=> a.id}
      cooks.each_with_index do |cook, num|
        if num == 0
          start_time = ordered_meal.ideal_served_time - cook.time * 60
          end_time = ordered_meal.ideal_served_time
        else
          start_time = @ajusted_start_time - cook.time * 60
          end_time = @ajusted_start_time
        end

        chef, @ajusted_end_time = search_chef(start_time, end_time, cook.skill, cook.is_free)
        @ajusted_start_time = @ajusted_end_time - cook.time * chef.cook_speed * 60
        Schedule.create!(chef_id: chef.id, cook_id: cook.id, ordered_meal_id: ordered_meal.id, start_time: @ajusted_start_time, end_time: @ajusted_end_time, is_free: cook.is_free)
      end
    end
  end

  def search_chef(start_time, end_time, skill, is_free)
    chefs = Chef.where(skill: skill.to_i..3).sort{|a, b| a.skill <=> b.skill}
    @end_time = end_time

    if is_free
      @chef = chefs.first
    else
      chefs.each do |chef|
        if chef.schedules.where(is_free: false).where('end_time > ? and ? > start_time', start_time, end_time).exists?
          if @end_time == end_time || @end_time < chef.schedules.where(is_free: false).minimum(:start_time)
            @end_time = chef.schedules.where(is_free: false).minimum(:start_time)
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
