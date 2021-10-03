class ProcessTime < ApplicationRecord
  def self.now
    self.first.now
  end

  def self.set_zero_time
    if self.first.present?
      self.destroy_all
    end
    self.create(now: Schedule.all.minimum(:start_time))
  end
end
