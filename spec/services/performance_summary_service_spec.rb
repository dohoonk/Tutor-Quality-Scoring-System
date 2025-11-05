# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PerformanceSummaryService do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let(:student) { Student.create!(name: 'Bob Student', email: 'bob@example.com') }
  let(:service) { PerformanceSummaryService.new(tutor) }

  describe '#generate_summary' do
    context 'with improving SQS trend' do
      before do
        # Create sessions with improving SQS scores
        5.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: (10 - i).days.ago,
            actual_start_at: (10 - i).days.ago,
            scheduled_end_at: (10 - i).days.ago + 1.hour,
            actual_end_at: (10 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
          
          # Scores improve over time: 70, 75, 80, 85, 90
          Score.create!(
            session: session,
            tutor: tutor,
            score_type: 'sqs',
            value: 70 + (i * 5),
            computed_at: (10 - i).days.ago
          )
        end
      end

      it 'identifies improving trend' do
        summary = service.generate_summary
        expect(summary[:trend]).to eq(:improving)
      end

      it 'generates encouraging message for improvement' do
        summary = service.generate_summary
        expect(summary[:summary]).to include('improving')
        expect(summary[:summary]).to include('sessions')
      end

      it 'highlights what went well' do
        summary = service.generate_summary
        expect(summary[:what_went_well]).to be_present
        expect(summary[:what_went_well]).to be_a(String)
      end

      it 'provides one improvement suggestion' do
        summary = service.generate_summary
        expect(summary[:improvement_suggestion]).to be_present
        expect(summary[:improvement_suggestion]).to be_a(String)
      end
    end

    context 'with declining SQS trend' do
      before do
        5.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: (10 - i).days.ago,
            actual_start_at: (10 - i).days.ago,
            scheduled_end_at: (10 - i).days.ago + 1.hour,
            actual_end_at: (10 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
          
          # Scores decline over time: 90, 85, 80, 75, 70
          Score.create!(
            session: session,
            tutor: tutor,
            score_type: 'sqs',
            value: 90 - (i * 5),
            computed_at: (10 - i).days.ago
          )
        end
      end

      it 'identifies declining trend' do
        summary = service.generate_summary
        expect(summary[:trend]).to eq(:declining)
      end

      it 'provides supportive message for decline' do
        summary = service.generate_summary
        expect(summary[:summary]).to include('sessions')
        expect(summary[:summary]).not_to include('concern') # Should be supportive, not alarming
      end

      it 'offers constructive improvement suggestion' do
        summary = service.generate_summary
        expect(summary[:improvement_suggestion]).to be_present
      end
    end

    context 'with stable SQS trend' do
      before do
        5.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: (10 - i).days.ago,
            actual_start_at: (10 - i).days.ago,
            scheduled_end_at: (10 - i).days.ago + 1.hour,
            actual_end_at: (10 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
          
          # Scores stay around 85 (±2)
          Score.create!(
            session: session,
            tutor: tutor,
            score_type: 'sqs',
            value: 85 + rand(-2..2),
            computed_at: (10 - i).days.ago
          )
        end
      end

      it 'identifies stable trend' do
        summary = service.generate_summary
        expect(summary[:trend]).to eq(:stable)
      end

      it 'acknowledges consistent performance' do
        summary = service.generate_summary
        expect(summary[:summary].downcase).to include('consist') # Matches "consistency" or "consistent"
      end
    end

    context 'with no sessions' do
      it 'returns appropriate message for new tutors' do
        summary = service.generate_summary
        expect(summary[:summary]).to include('first sessions')
        expect(summary[:trend]).to eq(:insufficient_data)
      end
    end

    context 'with very few sessions (< 3)' do
      before do
        2.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: (5 - i).days.ago,
            actual_start_at: (5 - i).days.ago,
            scheduled_end_at: (5 - i).days.ago + 1.hour,
            actual_end_at: (5 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
          
          Score.create!(
            session: session,
            tutor: tutor,
            score_type: 'sqs',
            value: 85,
            computed_at: (5 - i).days.ago
          )
        end
      end

      it 'indicates insufficient data' do
        summary = service.generate_summary
        expect(summary[:trend]).to eq(:insufficient_data)
      end

      it 'provides encouraging early feedback' do
        summary = service.generate_summary
        expect(summary[:summary]).to be_present
      end
    end

    context 'with high average scores (> 85)' do
      before do
        5.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: (10 - i).days.ago,
            actual_start_at: (10 - i).days.ago,
            scheduled_end_at: (10 - i).days.ago + 1.hour,
            actual_end_at: (10 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
          
          Score.create!(
            session: session,
            tutor: tutor,
            score_type: 'sqs',
            value: 90,
            computed_at: (10 - i).days.ago
          )
        end
      end

      it 'celebrates excellent performance' do
        summary = service.generate_summary
        expect(summary[:what_went_well]).to include('excellent')
      end
    end

    context 'with low average scores (< 70)' do
      before do
        5.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: (10 - i).days.ago,
            actual_start_at: (10 - i).days.ago,
            scheduled_end_at: (10 - i).days.ago + 1.hour,
            actual_end_at: (10 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
          
          Score.create!(
            session: session,
            tutor: tutor,
            score_type: 'sqs',
            value: 65,
            computed_at: (10 - i).days.ago
          )
        end
      end

      it 'provides supportive feedback' do
        summary = service.generate_summary
        expect(summary[:improvement_suggestion]).to be_present
      end

      it 'remains encouraging despite low scores' do
        summary = service.generate_summary
        # Should not use negative words
        expect(summary[:summary]).not_to include('poor')
        expect(summary[:summary]).not_to include('bad')
      end
    end
  end
end

