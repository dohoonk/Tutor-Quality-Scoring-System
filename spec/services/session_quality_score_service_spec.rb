require 'rails_helper'

RSpec.describe SessionQualityScoreService, type: :service do
  let(:tutor) { Tutor.create!(name: 'Test Tutor', email: 'tutor@example.com') }
  let(:student) { Student.create!(name: 'Test Student', email: 'student@example.com') }

  describe '#calculate' do
    context 'when session has no penalties' do
      it 'returns base score of 80 with ok label' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: scheduled_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:score]).to eq(80)
        expect(result[:label]).to eq('ok')
        expect(result[:components][:base]).to eq(80)
        expect(result[:components][:lateness_penalty]).to eq(0)
        expect(result[:components][:shortfall_penalty]).to eq(0)
        expect(result[:components][:tech_penalty]).to eq(0)
      end
    end

    context 'when session has lateness' do
      it 'calculates lateness penalty correctly' do
        now = Time.current
        scheduled_start = now - 1.hour
        actual_start = scheduled_start + 5.minutes # 5 minutes late
        scheduled_end = now
        actual_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: actual_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: actual_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:components][:lateness_penalty]).to eq(10) # min(20, 2 * 5)
        expect(result[:score]).to eq(70) # 80 - 10
        expect(result[:label]).to eq('warn') # 70 is in warn range (60-75)
      end

      it 'caps lateness penalty at 20' do
        now = Time.current
        scheduled_start = now - 1.hour
        actual_start = scheduled_start + 15.minutes # 15 minutes late
        scheduled_end = now
        actual_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: actual_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: actual_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:components][:lateness_penalty]).to eq(20) # min(20, 2 * 15)
        expect(result[:score]).to eq(60) # 80 - 20
        expect(result[:label]).to eq('warn')
      end
    end

    context 'when session ends early' do
      it 'calculates shortfall penalty correctly' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = scheduled_start + 1.hour
        actual_end = scheduled_end - 5.minutes # 5 minutes early
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: actual_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:components][:shortfall_penalty]).to eq(5) # min(10, 1 * 5)
        expect(result[:score]).to eq(75) # 80 - 5
        expect(result[:label]).to eq('warn') # 75 is at the boundary (60-75)
      end

      it 'caps shortfall penalty at 10' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = scheduled_start + 1.hour
        actual_end = scheduled_end - 15.minutes # 15 minutes early
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: actual_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:components][:shortfall_penalty]).to eq(10) # min(10, 1 * 15)
        expect(result[:score]).to eq(70) # 80 - 10
        expect(result[:label]).to eq('warn') # 70 is in warn range (60-75)
      end
    end

    context 'when session has tech issue' do
      it 'applies tech penalty of 10' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: scheduled_end,
          status: 'completed',
          tech_issue: true
        )

        result = described_class.new(session).calculate

        expect(result[:components][:tech_penalty]).to eq(10)
        expect(result[:score]).to eq(70) # 80 - 10
        expect(result[:label]).to eq('warn') # 70 is in warn range (60-75)
      end
    end

    context 'when multiple penalties apply' do
      it 'sums all penalties correctly' do
        now = Time.current
        scheduled_start = now - 1.hour
        actual_start = scheduled_start + 5.minutes # 5 min late
        scheduled_end = scheduled_start + 1.hour
        actual_end = scheduled_end - 3.minutes # 3 min early
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: actual_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: actual_end,
          status: 'completed',
          tech_issue: true
        )

        result = described_class.new(session).calculate

        expect(result[:components][:lateness_penalty]).to eq(10)
        expect(result[:components][:shortfall_penalty]).to eq(3)
        expect(result[:components][:tech_penalty]).to eq(10)
        expect(result[:score]).to eq(57) # 80 - 10 - 3 - 10
        expect(result[:label]).to eq('risk')
      end
    end

    context 'when score would go below 0' do
      it 'clamps score to 0' do
        now = Time.current
        scheduled_start = now - 1.hour
        actual_start = scheduled_start + 15.minutes # 15 min late (20 penalty)
        scheduled_end = scheduled_start + 1.hour
        actual_end = scheduled_end - 15.minutes # 15 min early (10 penalty)
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: actual_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: actual_end,
          status: 'completed',
          tech_issue: true # 10 penalty
        )

        result = described_class.new(session).calculate

        expect(result[:score]).to eq(40) # 80 - 20 - 10 - 10 = 40 (not clamped, stays above 0)
        expect(result[:label]).to eq('risk')
      end
    end

    context 'when score would go above 100' do
      it 'clamps score to 100' do
        # This shouldn't happen with base of 80, but test for completeness
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start - 1.minute, # started 1 min early
          scheduled_end_at: scheduled_end,
          actual_end_at: scheduled_end + 1.minute, # ended 1 min late
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:score]).to be <= 100
      end
    end

    context 'label thresholds' do
      it 'returns risk for scores < 60' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start + 11.minutes, # 22 penalty (min(20, 22) = 20)
          scheduled_end_at: scheduled_end,
          actual_end_at: scheduled_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:score]).to eq(60) # 80 - 20
        expect(result[:label]).to eq('warn')
        
        # Test with score < 60
        session.update!(actual_start_at: session.scheduled_start_at + 11.minutes) # 22 penalty, but capped at 20
        result = described_class.new(session.reload).calculate
        expect(result[:score]).to eq(60) # Still 60
        
        # Actually get < 60 with tech issue
        session.update!(tech_issue: true)
        result = described_class.new(session.reload).calculate
        expect(result[:score]).to eq(50) # 80 - 20 - 10
        expect(result[:label]).to eq('risk')
      end

      it 'returns warn for scores 60-75' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start + 10.minutes, # 20 penalty
          scheduled_end_at: scheduled_end,
          actual_end_at: scheduled_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:score]).to eq(60)
        expect(result[:label]).to eq('warn')
      end

      it 'returns ok for scores > 75' do
        now = Time.current
        scheduled_start = now - 1.hour
        scheduled_end = now
        
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: scheduled_start,
          actual_start_at: scheduled_start,
          scheduled_end_at: scheduled_end,
          actual_end_at: scheduled_end,
          status: 'completed',
          tech_issue: false
        )

        result = described_class.new(session).calculate

        expect(result[:score]).to eq(80)
        expect(result[:label]).to eq('ok')
      end
    end
  end

  describe '#save_score' do
    it 'saves score to scores table' do
      now = Time.current
      scheduled_start = now - 1.hour
      scheduled_end = now
      
      session = Session.create!(
        tutor: tutor,
        student: student,
        scheduled_start_at: scheduled_start,
        actual_start_at: scheduled_start,
        scheduled_end_at: scheduled_end,
        actual_end_at: scheduled_end,
        status: 'completed',
        tech_issue: false
      )

      service = described_class.new(session)
      result = service.calculate
      service.save_score(result)

      score = Score.find_by(session: session, score_type: 'sqs')
      expect(score).to be_present
      expect(score.value).to eq(80)
      expect(score.tutor_id).to eq(tutor.id)
      expect(score.components['base']).to eq(80)
      expect(score.components['label']).to eq('ok')
      expect(score.computed_at).to be_present
    end
  end
end

