class Score < ApplicationRecord
  belongs_to :tutor
  belongs_to :session, optional: true

  validates :score_type, presence: true, inclusion: { in: %w[sqs fsqs ths tcrs] }
  validates :value, presence: true
  validates :computed_at, presence: true
end

