# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlertJob, type: :job do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }

  describe '#perform' do
    context 'with high FSRS score (>= 50)' do
      before do
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'fsrs',
          value: 55.0,
          computed_at: Time.current
        )
      end

      it 'creates a poor_first_session alert' do
        expect {
          AlertJob.new.perform
        }.to change { Alert.where(alert_type: 'poor_first_session').count }.by(1)
      end

      it 'sets alert severity to high' do
        AlertJob.new.perform
        alert = Alert.find_by(tutor: tutor, alert_type: 'poor_first_session')
        expect(alert.severity).to eq('high')
      end

      it 'sets alert status to open' do
        AlertJob.new.perform
        alert = Alert.find_by(tutor: tutor, alert_type: 'poor_first_session')
        expect(alert.status).to eq('open')
      end
    end

    context 'with low THS score (< 55)' do
      before do
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'ths',
          value: 45.0,
          computed_at: Time.current
        )
      end

      it 'creates a high_reliability_risk alert' do
        expect {
          AlertJob.new.perform
        }.to change { Alert.where(alert_type: 'high_reliability_risk').count }.by(1)
      end
    end

    context 'with high TCRS score (>= 0.6)' do
      before do
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'tcrs',
          value: 0.7,
          computed_at: Time.current
        )
      end

      it 'creates a churn_risk alert' do
        expect {
          AlertJob.new.perform
        }.to change { Alert.where(alert_type: 'churn_risk').count }.by(1)
      end
    end

    context 'when alert condition persists' do
      before do
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'fsrs',
          value: 55.0,
          computed_at: Time.current
        )
        
        # Create existing open alert
        Alert.create!(
          tutor: tutor,
          alert_type: 'poor_first_session',
          severity: 'high',
          status: 'open',
          triggered_at: 1.hour.ago
        )
      end

      it 'does not create duplicate alerts' do
        expect {
          AlertJob.new.perform
        }.not_to change { Alert.where(alert_type: 'poor_first_session').count }
      end
    end

    context 'when alert condition improves' do
      let!(:alert) do
        Alert.create!(
          tutor: tutor,
          alert_type: 'poor_first_session',
          severity: 'high',
          status: 'open',
          triggered_at: 1.hour.ago
        )
      end

      before do
        # Create a good FSRS score
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'fsrs',
          value: 20.0, # Below 50 threshold
          computed_at: Time.current
        )
      end

      it 'resolves the alert' do
        AlertJob.new.perform
        alert.reload
        expect(alert.status).to eq('resolved')
        expect(alert.resolved_at).to be_present
      end
    end

    context 'with THS improving above 55' do
      let!(:alert) do
        Alert.create!(
          tutor: tutor,
          alert_type: 'high_reliability_risk',
          severity: 'high',
          status: 'open',
          triggered_at: 1.hour.ago
        )
      end

      before do
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'ths',
          value: 60.0, # Above 55 threshold
          computed_at: Time.current
        )
      end

      it 'resolves the reliability risk alert' do
        AlertJob.new.perform
        alert.reload
        expect(alert.status).to eq('resolved')
      end
    end

    context 'with TCRS improving below 0.6' do
      let!(:alert) do
        Alert.create!(
          tutor: tutor,
          alert_type: 'churn_risk',
          severity: 'high',
          status: 'open',
          triggered_at: 1.hour.ago
        )
      end

      before do
        Score.create!(
          tutor: tutor,
          session: nil,
          score_type: 'tcrs',
          value: 0.4, # Below 0.6 threshold
          computed_at: Time.current
        )
      end

      it 'resolves the churn risk alert' do
        AlertJob.new.perform
        alert.reload
        expect(alert.status).to eq('resolved')
      end
    end

    context 'with no risk conditions' do
      before do
        Score.create!(tutor: tutor, session: nil, score_type: 'fsrs', value: 20.0, computed_at: Time.current)
        Score.create!(tutor: tutor, session: nil, score_type: 'ths', value: 80.0, computed_at: Time.current)
        Score.create!(tutor: tutor, session: nil, score_type: 'tcrs', value: 0.2, computed_at: Time.current)
      end

      it 'does not create any alerts' do
        expect {
          AlertJob.new.perform
        }.not_to change { Alert.count }
      end
    end
  end
end
