class Tutor < ApplicationRecord
  validates :name, presence: true

  has_many :sessions, dependent: :destroy
  has_many :scores, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :tutor_daily_aggregates, dependent: :destroy
end
