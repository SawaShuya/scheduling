namespace :customers do
  desc "顧客の作成"
  task :create => :environment do
    number = 5
    velocity_range = 0.8..1.2
    meals = Meal.all
    open_time = Time.mktime(2020, 1, 1, 17, 0,0,6)
    reserve_timing = [0, 15, 30, 45, 60]

    number.times do |i|
      time = open_time + reserve_timing[rand(0..4)]*60
      customer = Customer.new(genre_id: rand(1..3), style_id: rand(1..3), velocity_params: rand(velocity_range).round(1), reserved_time: time)
      next_serve_time = time + 5 * 60
      if customer.save!
        meals.each do |meal|
          order_meal = customer.ordered_meals.new(meal_id: meal.id, ideal_served_time: next_serve_time)
          order_meal.save
          next_serve_time += (meal.eating_time + meal.interval) * customer.style.velocity_params * 60
        end
      end
    end

  end
end
