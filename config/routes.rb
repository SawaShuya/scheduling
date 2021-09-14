Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root "schedules#index"
  post "shcedules/csv" => "schedules#index", as: "post_csv"
end
