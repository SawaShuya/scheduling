namespace :setting do
  desc "再設定(顧客の生成、静的スケジューリング)"
  task :all => :environment do
    Customer.all.destroy_all
    Chef.reset_work_time
    Customer.create_samples
    ordered_meal_ids = OrderedMeal.all.pluck(:id)
    Schedule.backward_scheduling(nil, false, ordered_meal_ids)
    ProcessTime.set_zero_time
  end

  desc "顧客の作成"
  task :customer => :environment do
    Customer.all.destroy_all
    Chef.reset_work_time
    Customer.create_samples
  end

  desc '静的スケジューリング(顧客がいる前提)'
  task :schedule => :environment do
    Schedule.all.destroy_all
    Chef.reset_work_time
    ordered_meal_ids = OrderedMeal.all.pluck(:id)
    Schedule.backward_scheduling(nil, false, ordered_meal_ids)
    ProcessTime.set_zero_time
  end

  desc '顧客そのままで注文料理生成'
  task :ordered_meal => :environment do
    OrderedMeal.destroy_all
    Customer.create_all_ordered_meals
    Chef.reset_work_time
    ordered_meal_ids = OrderedMeal.all.pluck(:id)
    Schedule.backward_scheduling(nil, false, ordered_meal_ids)
    ProcessTime.set_zero_time
  end

  
end
