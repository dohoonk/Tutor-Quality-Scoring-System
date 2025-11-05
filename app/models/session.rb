class Session < ApplicationRecord
  belongs_to :tutor
  belongs_to :student
  has_one :session_transcript, dependent: :destroy
end
