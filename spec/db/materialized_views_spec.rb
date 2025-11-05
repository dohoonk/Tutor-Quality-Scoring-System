require 'rails_helper'

RSpec.describe 'materialized views', type: :model do
  describe 'tutor_stats_7d' do
    it 'exists in the database' do
      result = ActiveRecord::Base.connection.execute(
        "SELECT matviewname FROM pg_matviews WHERE matviewname = 'tutor_stats_7d'"
      )
      expect(result.any?).to be true
    end

    it 'can be queried and has expected columns' do
      # Query the view to verify it exists and has the right structure
      expect {
        ActiveRecord::Base.connection.execute(
          "SELECT tutor_id, sessions_completed_7d, reschedules_tutor_initiated_7d, no_shows_7d, avg_lateness_min_7d FROM tutor_stats_7d LIMIT 1"
        )
      }.not_to raise_error
    end
  end

  describe 'tutor_stats_14d' do
    it 'exists in the database' do
      result = ActiveRecord::Base.connection.execute(
        "SELECT matviewname FROM pg_matviews WHERE matviewname = 'tutor_stats_14d'"
      )
      expect(result.any?).to be true
    end

    it 'can be queried and has expected columns' do
      # Query the view to verify it exists and has the right structure
      expect {
        ActiveRecord::Base.connection.execute(
          "SELECT tutor_id, sessions_completed_14d, availability_14d, repeat_student_rate_14d FROM tutor_stats_14d LIMIT 1"
        )
      }.not_to raise_error
    end
  end
end
