require 'rails_helper'

RSpec.describe AlertService, type: :service do
  let(:tutor) { Tutor.create!(name: 'Test Tutor', email: 'tutor@example.com') }

  describe '#evaluate_and_create_alerts' do
    context 'when FSRS ≥ 50' do
      it 'creates a poor_first_session alert' do
        # Create a high FSRS score
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'fsqs',
          value: 55,
          components: { score: 55 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alert = Alert.find_by(tutor: tutor, alert_type: 'low_first_session_quality')
        expect(alert).to be_present
        expect(alert.severity).to eq('high')
        expect(alert.status).to eq('open')
        expect(alert.triggered_at).to be_present
      end
    end

    context 'when THS < 55' do
      it 'creates a high_reliability_risk alert' do
        # Create a low THS score
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'ths',
          value: 50,
          components: { score: 50 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alert = Alert.find_by(tutor: tutor, alert_type: 'high_reliability_risk')
        expect(alert).to be_present
        expect(alert.severity).to eq('high')
        expect(alert.status).to eq('open')
      end
    end

    context 'when TCRS ≥ 0.6' do
      it 'creates a churn_risk alert' do
        # Create a high TCRS score
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'tcrs',
          value: 0.65,
          components: { score: 0.65 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alert = Alert.find_by(tutor: tutor, alert_type: 'churn_risk')
        expect(alert).to be_present
        expect(alert.severity).to eq('high')
        expect(alert.status).to eq('open')
      end
    end

    context 'when multiple conditions are met' do
      it 'creates multiple alerts' do
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'fsqs',
          value: 55,
          components: { score: 55 },
          computed_at: Time.current
        )
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'ths',
          value: 50,
          components: { score: 50 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alerts = Alert.where(tutor: tutor)
        expect(alerts.count).to eq(2)
        expect(alerts.pluck(:alert_type)).to contain_exactly('low_first_session_quality', 'high_reliability_risk')
      end
    end

    context 'when conditions do not meet thresholds' do
      it 'does not create alerts' do
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'fsqs',
          value: 40, # Below threshold
          components: { score: 40 },
          computed_at: Time.current
        )
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'ths',
          value: 60, # Above threshold
          components: { score: 60 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alerts = Alert.where(tutor: tutor)
        expect(alerts.count).to eq(0)
      end
    end

    context 'when alert already exists and condition persists' do
      it 'does not create duplicate alert - keeps existing alert open' do
        # Create existing alert
        existing_alert = Alert.create!(
          tutor: tutor,
          alert_type: 'low_first_session_quality',
          severity: 'medium',
          status: 'open',
          triggered_at: 1.hour.ago
        )

        # Create score that would trigger same alert (condition still bad)
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'fsqs',
          value: 55,
          components: { score: 55 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alerts = Alert.where(tutor: tutor, alert_type: 'low_first_session_quality', status: 'open')
        expect(alerts.count).to eq(1)
        expect(alerts.first.id).to eq(existing_alert.id)
        expect(alerts.first.resolved_at).to be_nil
      end
    end

    context 'when conditions improve' do
      it 'auto-resolves existing alerts' do
        # Create existing alert
        alert = Alert.create!(
          tutor: tutor,
          alert_type: 'low_first_session_quality',
          severity: 'medium',
          status: 'open',
          triggered_at: 1.hour.ago
        )

        # Create improved score
        Score.create!(
          session: nil,
          tutor: tutor,
          score_type: 'fsqs',
          value: 40, # Below threshold now
          components: { score: 40 },
          computed_at: Time.current
        )

        described_class.new.evaluate_and_create_alerts(tutor)

        alert.reload
        expect(alert.status).to eq('resolved')
        expect(alert.resolved_at).to be_present
      end
    end

    context 'when no scores exist' do
      it 'does not create alerts' do
        described_class.new.evaluate_and_create_alerts(tutor)

        alerts = Alert.where(tutor: tutor)
        expect(alerts.count).to eq(0)
      end
    end
  end

  describe '#evaluate_all_tutors' do
    it 'evaluates alerts for all tutors' do
      tutor1 = Tutor.create!(name: 'Tutor 1', email: 'tutor1@example.com')
      tutor2 = Tutor.create!(name: 'Tutor 2', email: 'tutor2@example.com')

      Score.create!(
        session: nil,
        tutor: tutor1,
        score_type: 'fsqs',
        value: 55,
        components: { score: 55 },
        computed_at: Time.current
      )
      Score.create!(
        session: nil,
        tutor: tutor2,
        score_type: 'ths',
        value: 50,
        components: { score: 50 },
        computed_at: Time.current
      )

      described_class.new.evaluate_all_tutors

      expect(Alert.where(tutor: tutor1).count).to eq(1)
      expect(Alert.where(tutor: tutor2).count).to eq(1)
    end
  end
end

