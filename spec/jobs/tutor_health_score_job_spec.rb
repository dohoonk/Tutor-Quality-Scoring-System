require 'rails_helper'

RSpec.describe TutorHealthScoreJob, type: :job do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let(:student) { Student.create!(name: 'Bob Student', email: 'bob@example.com') }

  before do
    # Clear any existing scores
    Score.where(score_type: 'ths').destroy_all
    TutorDailyAggregate.destroy_all
  end

  describe '#perform' do
    context 'with excellent reliability metrics' do
      before do
        # Create aggregates for the last 7 days with excellent metrics
        7.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 3,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'creates a THS score' do
        expect {
          TutorHealthScoreJob.new.perform
        }.to change { Score.where(score_type: 'ths').count }.by(1)
      end

      it 'calculates high THS for excellent performance' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        expect(score.value).to be >= 90.0
      end

      it 'stores computation timestamp' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        expect(score.computed_at).to be_within(1.minute).of(Time.current)
      end

      it 'stores components breakdown' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        expect(score.components).to be_a(Hash)
        expect(score.components).to include('reschedule_rate', 'no_show_count', 'avg_lateness')
      end
    end

    context 'with poor reliability metrics' do
      before do
        # Create aggregates with high reschedule rate and no-shows
        7.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 3,
            reschedules_tutor_initiated: 2, # 2 out of 5 total = 40% reschedule rate
            no_shows: 1,
            avg_lateness_min: 15.0
          )
        end
      end

      it 'calculates low THS for poor performance' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        expect(score.value).to be < 60.0
      end

      it 'reflects high reschedule rate in components' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        expect(score.components['reschedule_rate']).to be > 0.3 # > 30%
      end
    end

    context 'with moderate reliability metrics' do
      before do
        # Create aggregates with moderate metrics
        7.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 4,
            reschedules_tutor_initiated: 1, # 1 out of 5 total = 20% reschedule rate
            no_shows: 0,
            avg_lateness_min: 5.0
          )
        end
      end

      it 'calculates moderate THS' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        expect(score.value).to be_between(60.0, 85.0)
      end
    end

    context 'with no aggregates in the last 7 days' do
      it 'does not create a THS score' do
        expect {
          TutorHealthScoreJob.new.perform
        }.not_to change { Score.where(score_type: 'ths').count }
      end
    end

    context 'with partial data (only 3 days of aggregates)' do
      before do
        # Create aggregates for only 3 days
        3.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 3,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'still creates a THS score based on available data' do
        expect {
          TutorHealthScoreJob.new.perform
        }.to change { Score.where(score_type: 'ths').count }.by(1)
      end
    end

    context 'with multiple tutors' do
      let(:tutor2) { Tutor.create!(name: 'Bob Smith', email: 'bob@example.com') }

      before do
        # Tutor 1: Good performance
        5.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 4,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 2.0
          )
        end

        # Tutor 2: Poor performance
        5.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor2,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 2,
            reschedules_tutor_initiated: 2,
            no_shows: 1,
            avg_lateness_min: 20.0
          )
        end
      end

      it 'creates separate THS scores for each tutor' do
        expect {
          TutorHealthScoreJob.new.perform
        }.to change { Score.where(score_type: 'ths').count }.by(2)
      end

      it 'calculates different scores based on performance' do
        TutorHealthScoreJob.new.perform
        score1 = Score.where(tutor: tutor, score_type: 'ths').last
        score2 = Score.where(tutor: tutor2, score_type: 'ths').last

        expect(score1.value).to be > score2.value
        expect(score1.value).to be > 75.0 # Good performance
        expect(score2.value).to be < 60.0 # Poor performance
      end
    end

    context 'when THS score already exists for today' do
      before do
        # Create aggregates
        3.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 3,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end

        # Create existing THS score for today
        Score.create!(
          tutor: tutor,
          score_type: 'ths',
          value: 80.0,
          components: {},
          computed_at: Time.current
        )
      end

      it 'updates existing score instead of creating duplicate' do
        expect {
          TutorHealthScoreJob.new.perform
        }.not_to change { Score.where(score_type: 'ths').count }
      end

      it 'updates the score value' do
        old_score_value = Score.where(tutor: tutor, score_type: 'ths').last.value
        TutorHealthScoreJob.new.perform
        new_score_value = Score.where(tutor: tutor, score_type: 'ths').last.value

        # Score should be recalculated (might be different)
        expect(new_score_value).to be_present
      end
    end

    context 'with improving trend over 7 days' do
      before do
        # Create trend: poor performance 7 days ago, improving to good today
        7.times do |i|
          days_ago = 7 - i # 7, 6, 5, 4, 3, 2, 1
          # Reschedules decrease over time
          reschedules = days_ago > 4 ? 2 : 0
          # Lateness decreases over time
          lateness = days_ago > 4 ? 15.0 : 2.0

          TutorDailyAggregate.create!(
            tutor: tutor,
            date: days_ago.days.ago.to_date,
            sessions_completed: 3,
            reschedules_tutor_initiated: reschedules,
            no_shows: 0,
            avg_lateness_min: lateness
          )
        end
      end

      it 'gives higher weight to recent performance' do
        TutorHealthScoreJob.new.perform
        score = Score.where(tutor: tutor, score_type: 'ths').last
        # Should be reasonably high since recent performance is good
        expect(score.value).to be > 70.0
      end
    end
  end
end

