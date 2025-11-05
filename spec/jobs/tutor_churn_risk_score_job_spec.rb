require 'rails_helper'

RSpec.describe TutorChurnRiskScoreJob, type: :job do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }

  describe '#perform' do
    context 'with stable engagement (low churn risk)' do
      before do
        # Consistent high activity over 14 days
        14.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 3, # Consistent 3 sessions per day
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 2.0
          )
        end
      end

      it 'creates a TCRS score' do
        expect {
          TutorChurnRiskScoreJob.new.perform
        }.to change { Score.where(score_type: 'tcrs').count }.by(1)
      end

      it 'calculates low TCRS for stable engagement' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.value).to be <= 0.3 # Low risk threshold
      end

      it 'stores computation timestamp' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.computed_at).to be_within(1.second).of(Time.current)
      end

      it 'stores components breakdown' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components).to be_present
        expect(score.components).to include(
          'session_count',
          'avg_daily_sessions',
          'consistency_score'
        )
      end
    end

    context 'with declining engagement (high churn risk)' do
      before do
        # Declining activity: 3 sessions/day → 0 sessions/day
        14.times do |i|
          sessions = i < 7 ? 3 : 0 # Active for first 7 days, inactive for last 7
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (14 - i).days.ago.to_date, # Most recent = index 13
            sessions_completed: sessions,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'calculates high TCRS for declining engagement' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.value).to be >= 0.6 # High risk threshold
      end

      it 'reflects declining trend in components' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components['trend']).to eq('declining')
      end
    end

    context 'with very low activity (disengagement signal)' do
      before do
        # Very few sessions over 14 days
        14.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: i < 2 ? 1 : 0, # Only 2 sessions total
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'calculates high TCRS for low activity' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.value).to be >= 0.6 # High risk
      end

      it 'reflects low session count in components' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components['session_count']).to eq(2)
        expect(score.components['avg_daily_sessions']).to be < 0.5
      end
    end

    context 'with inconsistent activity (moderate churn risk)' do
      before do
        # Erratic pattern: 5, 0, 3, 0, 2, 0, 4, 0, ...
        14.times do |i|
          sessions = i.even? ? [2, 3, 4, 5][i % 4] : 0
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: sessions,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'calculates moderate TCRS for inconsistent activity' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.value).to be_between(0.3, 0.6) # Moderate risk range
      end

      it 'reflects high variance in components' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components['consistency_score']).to be < 0.5 # Low consistency
      end
    end

    context 'with no aggregates in the last 14 days' do
      it 'does not create a TCRS score' do
        expect {
          TutorChurnRiskScoreJob.new.perform
        }.not_to change { Score.where(tutor: tutor, score_type: 'tcrs').count }
      end
    end

    context 'with partial data (only 7 days of aggregates)' do
      before do
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

      it 'still creates a TCRS score based on available data' do
        expect {
          TutorChurnRiskScoreJob.new.perform
        }.to change { Score.where(tutor: tutor, score_type: 'tcrs').count }.by(1)
      end

      it 'adjusts risk calculation for partial data' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components['days_of_data']).to eq(7)
      end
    end

    context 'with multiple tutors' do
      let(:tutor2) { Tutor.create!(name: 'Bob Jones', email: 'bob@example.com') }

      before do
        # Tutor 1: Stable (low risk)
        5.times do |i|
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (i + 1).days.ago.to_date,
            sessions_completed: 4,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end

        # Tutor 2: Declining (high risk)
        5.times do |i|
          sessions = i < 2 ? 5 : 0 # Active then drops off
          TutorDailyAggregate.create!(
            tutor: tutor2,
            date: (5 - i).days.ago.to_date,
            sessions_completed: sessions,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'creates separate TCRS scores for each tutor' do
        expect {
          TutorChurnRiskScoreJob.new.perform
        }.to change { Score.where(score_type: 'tcrs').count }.by(2)

        score1 = Score.find_by(tutor: tutor, score_type: 'tcrs')
        score2 = Score.find_by(tutor: tutor2, score_type: 'tcrs')

        expect(score1).to be_present
        expect(score2).to be_present
      end

      it 'calculates different scores based on engagement patterns' do
        TutorChurnRiskScoreJob.new.perform

        score1 = Score.find_by(tutor: tutor, score_type: 'tcrs')
        score2 = Score.find_by(tutor: tutor2, score_type: 'tcrs')

        expect(score1.value).to be < score2.value # Stable tutor has lower risk
      end
    end

    context 'when TCRS score already exists for today' do
      before do
        # Create some aggregates
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

        # Create existing TCRS score for today
        Score.create!(
          tutor: tutor,
          score_type: 'tcrs',
          value: 0.5,
          computed_at: Time.current,
          components: { previous: true }
        )
      end

      it 'updates existing score instead of creating duplicate' do
        expect {
          TutorChurnRiskScoreJob.new.perform
        }.not_to change { Score.where(tutor: tutor, score_type: 'tcrs').count }
      end

      it 'updates the score value' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components).not_to include('previous' => true) # New components
      end
    end

    context 'with improving trend (recovering engagement)' do
      before do
        # Improving: 0 sessions → 3 sessions per day
        14.times do |i|
          sessions = i < 7 ? 0 : 3 # Inactive for first 7 days, active for last 7
          TutorDailyAggregate.create!(
            tutor: tutor,
            date: (14 - i).days.ago.to_date, # Most recent = index 13
            sessions_completed: sessions,
            reschedules_tutor_initiated: 0,
            no_shows: 0,
            avg_lateness_min: 0.0
          )
        end
      end

      it 'calculates lower TCRS for improving engagement' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        # Should be moderate risk (recovering, but still has gaps)
        expect(score.value).to be_between(0.2, 0.5)
      end

      it 'reflects improving trend in components' do
        TutorChurnRiskScoreJob.new.perform
        score = Score.find_by(tutor: tutor, score_type: 'tcrs')
        expect(score.components['trend']).to eq('improving')
      end
    end
  end
end

