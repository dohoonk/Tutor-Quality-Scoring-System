class Tutor < ApplicationRecord
  validates :name, presence: true

  has_many :sessions, dependent: :destroy
  has_many :scores, dependent: :destroy
  has_many :alerts, dependent: :destroy
end
