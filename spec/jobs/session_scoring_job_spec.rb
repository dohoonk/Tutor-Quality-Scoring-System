# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionScoringJob, type: :job do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let(:student) { Student.create!(name: 'Bob Student', email: 'bob@example.com') }

  describe '#perform' do
    context 'with completed sessions without scores' do
      let!(:session1) do
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 2.hours.ago,
          actual_start_at: 1.hour.ago + 5.minutes, # 5 min late
          scheduled_end_at: 1.hour.ago,
          actual_end_at: 30.minutes.ago, # 30 min short
          status: 'completed',
          tech_issue: false,
          first_session_for_student: false
        )
      end

      let!(:session2) do
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 3.days.ago,
          actual_start_at: 3.days.ago,
          scheduled_end_at: 3.days.ago + 1.hour,
          actual_end_at: 3.days.ago + 1.hour,
          status: 'completed',
          tech_issue: false,
          first_session_for_student: false
        )
      end

      it 'creates SQS scores for completed sessions without scores' do
        expect {
          SessionScoringJob.new.perform
        }.to change { Score.where(score_type: 'sqs').count }.by(2)
      end

      it 'calculates correct SQS based on lateness and duration shortfall' do
        SessionScoringJob.new.perform

        score1 = Score.find_by(session: session1, score_type: 'sqs')
        expect(score1).to be_present
        expect(score1.value).to be < 100 # Should be penalized for lateness and short duration
      end

      it 'gives perfect SQS for on-time, full-duration sessions' do
        SessionScoringJob.new.perform

        score2 = Score.find_by(session: session2, score_type: 'sqs')
        expect(score2).to be_present
        expect(score2.value).to eq(100.0)
      end

      it 'stores breakdown in components' do
        SessionScoringJob.new.perform

        score = Score.find_by(session: session1, score_type: 'sqs')
        expect(score.components).to include('lateness_penalty')
        expect(score.components).to include('duration_penalty')
      end
    end

    context 'with first session that has transcript' do
      let!(:first_session) do
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.day.ago,
          actual_start_at: 1.day.ago,
          scheduled_end_at: 1.day.ago + 1.hour,
          actual_end_at: 1.day.ago + 1.hour,
          status: 'completed',
          tech_issue: false,
          first_session_for_student: true
        )
      end

      let!(:transcript) do
        SessionTranscript.create!(
          session: first_session,
          payload: {
            text: 'This is confusing. I don\'t understand. You should try harder.'
          }
        )
      end

      it 'creates FSRS score for first sessions with transcripts' do
        expect {
          SessionScoringJob.new.perform
        }.to change { Score.where(score_type: 'fsqs').count }.by(1)
      end

      it 'calculates FSRS based on transcript content' do
        SessionScoringJob.new.perform

        fsrs_score = Score.find_by(session: first_session, score_type: 'fsqs')
        expect(fsrs_score).to be_present
        expect(fsrs_score.value).to be > 0 # Should detect issues in transcript
      end

      it 'stores FSRS breakdown in components' do
        SessionScoringJob.new.perform

        fsrs_score = Score.find_by(session: first_session, score_type: 'fsqs')
        expect(fsrs_score.components).to include('confusion_phrases')
        expect(fsrs_score.components).to include('negative_phrasing')
      end
    end

    context 'with already scored sessions' do
      let!(:session) do
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.day.ago,
          actual_start_at: 1.day.ago,
          scheduled_end_at: 1.day.ago + 1.hour,
          actual_end_at: 1.day.ago + 1.hour,
          status: 'completed',
          tech_issue: false,
          first_session_for_student: false
        )
      end

      let!(:existing_score) do
        Score.create!(
          session: session,
          tutor: tutor,
          score_type: 'sqs',
          value: 85.0,
          computed_at: 1.hour.ago
        )
      end

      it 'skips sessions that already have scores' do
        expect {
          SessionScoringJob.new.perform
        }.not_to change { Score.where(score_type: 'sqs').count }
      end
    end

    context 'with non-completed sessions' do
      let!(:scheduled_session) do
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.from_now,
          scheduled_end_at: 2.hours.from_now,
          status: 'scheduled',
          tech_issue: false,
          first_session_for_student: false
        )
      end

      it 'skips non-completed sessions' do
        expect {
          SessionScoringJob.new.perform
        }.not_to change { Score.count }
      end
    end
  end
end

