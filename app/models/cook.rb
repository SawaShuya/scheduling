class Cook < ApplicationRecord
  belongs_to :place
  belongs_to :meal

end
