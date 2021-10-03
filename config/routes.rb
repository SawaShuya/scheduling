Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root "schedules#index"
  get "schedules/moment" => "schedules#show", as: "moment"
  patch "schedules/next" => "schedules#next_time", as: "next_time"

  post "outputs" => "outputs#send_csv", as: "post_csv"

  patch "active" => "schedules#active", as: "active"
end
