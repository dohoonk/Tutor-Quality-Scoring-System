class Alert < ApplicationRecord
  belongs_to :tutor

  validates :alert_type, presence: true, inclusion: { in: %w[poor_first_session high_reliability_risk churn_risk] }
  validates :severity, presence: true, inclusion: { in: %w[high medium low] }
  validates :status, presence: true, inclusion: { in: %w[open resolved acknowledged] }
  validates :triggered_at, presence: true

  scope :open, -> { where(status: 'open') }
  scope :resolved, -> { where(status: 'resolved') }
end

