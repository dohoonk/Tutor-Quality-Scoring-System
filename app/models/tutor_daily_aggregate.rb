class TutorDailyAggregate < ApplicationRecord
  belongs_to :tutor

  validates :date, presence: true
  validates :tutor_id, uniqueness: { scope: :date }
  validates :sessions_completed, numericality: { greater_than_or_equal_to: 0 }
  validates :reschedules_tutor_initiated, numericality: { greater_than_or_equal_to: 0 }
  validates :no_shows, numericality: { greater_than_or_equal_to: 0 }
  validates :avg_lateness_min, numericality: { greater_than_or_equal_to: 0 }
end

