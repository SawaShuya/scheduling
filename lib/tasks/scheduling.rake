namespace :scheduling do
  desc "予約のみスケジューリング　料理抽出→調理ばらし"
  task :create => :environment do
    Schedule.all.destroy_all
    ordered_meals = OrderedMeal.all.includes(meal: :cooks).sort{|a, b| b.ideal_served_time <=> a.ideal_served_time}

    ordered_meals.each do |ordered_meal|
      cooks = ordered_meal.meal.cooks.sort{|a, b| b.id <=> a.id}
      cooks.each_with_index do |cook, num|
        if num == 0
          start_time = ordered_meal.ideal_served_time - cook.time * 60
          end_time = ordered_meal.ideal_served_time
        elsif cook.rear_cooks.present?
          rear_cook_id = Relationship.find_by(ahead_id: cook.id).rear_id
          end_time = ordered_meal.schedules.find_by(cook_id: rear_cook_id).start_time
          start_time = ordered_meal.schedules.find_by(cook_id: rear_cook_id).start_time - cook.time * 60
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


  task '予約スケジューリング 調理ばらし'
  task :create2 => :environment do
    Schedule.all.destroy_all
    customers= Customer.all

    staging_cooks = []

    customers.each do |customer|
      #[[調理終了時間, 調理工程, 注文料理id]]
      staging_cooks << [customer.ordered_meals.last.ideal_served_time, customer.ordered_meals.last.meal.cooks.last, customer.ordered_meals.last.id]
    end
    # byebug
    while staging_cooks.length != 0 do
      end_time = staging_cooks.max[0]
      cook = staging_cooks.max[1]
      ordered_meal_id = staging_cooks.max[2]

      start_time = end_time - cook.time * 60

      chef, @ajusted_end_time = search_chef(start_time, end_time, cook.skill, cook.is_free)
      @ajusted_start_time = @ajusted_end_time - cook.time * chef.cook_speed * 60

      Schedule.create!(chef_id: chef.id, cook_id: cook.id, ordered_meal_id: ordered_meal_id, start_time: @ajusted_start_time, end_time: @ajusted_end_time, is_free: cook.is_free)
      
      p end_time, cook.id, ordered_meal_id
      next_cook = Cook.find_by(id: cook.id - 1)
      index = staging_cooks.each_with_index.max[1]
      if next_cook.present?
        staging_cooks[index][0] = @ajusted_start_time
        staging_cooks[index][1] = next_cook
        staging_cooks[index][2] -= 1 if cook.meal.id != next_cook.meal.id
      else
        staging_cooks.delete_at(index)
      end
    end




  end


end
