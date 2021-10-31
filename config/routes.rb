Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root "schedules#index"
  get "schedules/moment" => "schedules#show", as: "moment"
  patch "schedules/next" => "schedules#next_time", as: "next_time"
  patch "schedules/reset_all" => "schedules#reset_all", as: "reset_all"
  patch "schedules/reset_ordered_meal" => "schedules#reset_ordered_meal", as: "reset_ordered_meal"
  patch "schedules/repetition" => "schedules#repetition", as: "repetition"

  post "outputs" => "outputs#send_csv", as: "post_csv"
  patch "active" => "schedules#active", as: "active"
end
