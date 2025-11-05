class Student < ApplicationRecord
  validates :name, presence: true

  has_many :sessions, dependent: :destroy
end
