class Relationship < ApplicationRecord
  belongs_to :ahead, class_name: "Cook", foreign_key: :ahead_id
  belongs_to :rear, class_name: "Cook", foreign_key: :rear_id
end
