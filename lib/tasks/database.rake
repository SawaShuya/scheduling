namespace :database do
  desc "予約のみスケジューリング"
  task :remove => :environment do
    Customer.all.destroy_all
  end
  
end
