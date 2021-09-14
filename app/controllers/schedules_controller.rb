class SchedulesController < ApplicationController
  require 'csv'

  def index
    @chefs = Chef.all
    @customers = Customer.all.includes(:style).sort{|a, b| a.reserved_time <=> b.reserved_time}
    respond_to do |format|
      format.html
      format.csv do |csv|
        send_csv(@customers, @chefs)
      end
    end
  end

  private
  def send_csv(customers, chefs)
    csv_data = CSV.generate(encoding: Encoding::SJIS) do |csv|
      csv << [0, "顧客"]
      column_name = ["id", "予約時間", "顧客形態", "固有食事ペース"]
      5.times do |i|
        column_name.concat ["#"+(i+1).to_s+"理想", "#"+(i+1).to_s+"予定"] 
      end
      csv << column_name
      customers.each do |customer|
        values =[]
        customer.ordered_meals.each do |ordered_meal|
          values.concat [ordered_meal.ideal_served_time.strftime("%H:%M"), ordered_meal.schedules.first.end_time.strftime("%H:%M")]
        end

        column_values = [
          customer.id,
          customer.reserved_time.strftime("%H:%M"),
          customer.style.id,
          customer.speed
        ]
        column_values.concat values
        csv << column_values
      end
      csv << []
      csv << [1, "スケジューリング"]
      column_name = %W(シェフ 顧客 料理名 調理id 順番 料理工程名 必要スキル 開始時間 終了時間)
      csv << column_name
      chefs.each do |chef|
        schedules = chef.schedules.includes(:cook, :ordered_meal).sort{|a, b| a.start_time <=> b.start_time}
        schedules.each_with_index do |schedule, i|
          id = chef.id if i == 0
          column_values = [
            id,
            schedule.ordered_meal.customer_id,
            schedule.ordered_meal.meal.name,
            schedule.cook.id,
            schedule.cook.permutation,
            schedule.cook.name,
            schedule.cook.skill,
            schedule.start_time.strftime("%H:%M"),
            schedule.end_time.strftime("%H:%M")
          ]
          csv << column_values
        end
      end
      csv << ["設定値"]
      csv << [3, "シェフ"]
      column_name = %W(id スキルレベル)
      csv << column_name
      chefs.each do |chef|
        column_values = [
          chef.id,
          chef.skill
        ]
        csv << column_values
      end

      csv << []
      csv << [4, "食事"]
      column_name = %W(食事名 基本食事時間 基本インターバル 調理id 順番 調理工程名 調理時間 必要スキル 調理場id 同時調理可能性 先行調理id)
      csv << column_name
      meals = Meal.all
      meals.each do |meal|
        meal.cooks.includes(:place).each_with_index do |cook, i|
          name = meal.name if i == 0
          eating_time = meal.eating_time if i == 0
          interval = meal.interval if i == 0
          column_values = [
            name,
            eating_time,
            interval,
            cook.id,
            cook.permutation,
            cook.name,
            cook.time,
            cook.skill,
            cook.place_id,
            cook.is_free,
            cook.ahead_cooks.pluck(:id).join(",")
          ]
          csv << column_values
        end
      end
      csv << []
      csv << [5, "調理場所"]
      column_name = %W(id 調理場名)
      csv << column_name
      places = Place.all
      places.each do |place|
        column_values = [
          place.id,
          place.name
        ]
        csv << column_values
      end

      csv << []
      csv << [6, "顧客形態"]
      column_name = %W(id 分類名 パラメータ)
      csv << column_name
      styles = Style.all
      styles.each do |style|
        column_values = [
          style.id,
          style.name,
          style.velocity_params
        ]
        csv << column_values
      end



    end

    time = Time.current.strftime("%Y%H%M")
    send_data(csv_data, filename: time + ".csv")
  end


end
