class SessionTranscript < ApplicationRecord
  belongs_to :session

  validates :payload, presence: true
end
