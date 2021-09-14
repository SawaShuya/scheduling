class Cook < ApplicationRecord
  belongs_to :place
  belongs_to :meal
  has_many :schedules

  has_many :rear_relationships, class_name: 'Relationship', foreign_key: :rear_id
  has_many :ahead_cooks, through: :rear_relationships, source: :ahead

  has_many :ahead_relationships, class_name: 'Relationship', foreign_key: :ahead_id
  has_many :rear_cooks, through: :ahead_relationships, source: :rear

end
