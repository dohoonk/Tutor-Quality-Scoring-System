require 'rails_helper'

RSpec.describe AlertMailer, type: :mailer do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let(:admin_email) { 'admin@example.com' }

  describe '#poor_first_session_alert' do
    let(:alert) do
      Alert.create!(
        tutor: tutor,
        alert_type: 'low_first_session_quality',
        severity: 'high',
        status: 'open',
        triggered_at: Time.current,
        metadata: {
          score_value: 55.0,
          score_components: {
            confusion_phrases: 2,
            negative_phrasing: 1,
            missing_goal_setting: 1
          }
        }
      )
    end

    let(:mail) { AlertMailer.poor_first_session_alert(alert, admin_email) }

    it 'renders the headers' do
      expect(mail.subject).to eq('🚨 Alert: Poor First Session Detected')
      expect(mail.to).to eq([admin_email])
      expect(mail.from).to eq(['noreply@tutor-insights.com'])
    end

    it 'includes tutor name in body' do
      expect(mail.body.encoded).to include(tutor.name)
    end

    it 'includes FSRS score in body' do
      expect(mail.body.encoded).to include('55.0')
    end

    it 'includes link to admin dashboard' do
      expect(mail.body.encoded).to include('http://example.com/admin/1')
    end

    it 'includes score breakdown' do
      expect(mail.body.encoded).to include('Confusion phrases')
      expect(mail.body.encoded).to include('Negative phrasing')
    end
  end

  describe '#high_reliability_risk_alert' do
    let(:alert) do
      Alert.create!(
        tutor: tutor,
        alert_type: 'high_reliability_risk',
        severity: 'high',
        status: 'open',
        triggered_at: Time.current,
        metadata: {
          score_value: 45.0,
          ths_below_threshold: true
        }
      )
    end

    let(:mail) { AlertMailer.high_reliability_risk_alert(alert, admin_email) }

    it 'renders the headers' do
      expect(mail.subject).to eq('⚠️ Alert: High Reliability Risk Detected')
      expect(mail.to).to eq([admin_email])
      expect(mail.from).to eq(['noreply@tutor-insights.com'])
    end

    it 'includes tutor name in body' do
      expect(mail.body.encoded).to include(tutor.name)
    end

    it 'includes THS score in body' do
      expect(mail.body.encoded).to include('45.0')
    end

    it 'includes link to admin dashboard' do
      expect(mail.body.encoded).to include('http://example.com/admin/1')
    end
  end

  describe '#churn_risk_alert' do
    let(:alert) do
      Alert.create!(
        tutor: tutor,
        alert_type: 'churn_risk',
        severity: 'high',
        status: 'open',
        triggered_at: Time.current,
        metadata: {
          score_value: 0.75,
          engagement_drop: true,
          low_session_count: true
        }
      )
    end

    let(:mail) { AlertMailer.churn_risk_alert(alert, admin_email) }

    it 'renders the headers' do
      expect(mail.subject).to eq('🚨 Alert: Tutor Churn Risk Detected')
      expect(mail.to).to eq([admin_email])
      expect(mail.from).to eq(['noreply@tutor-insights.com'])
    end

    it 'includes tutor name in body' do
      expect(mail.body.encoded).to include(tutor.name)
    end

    it 'includes TCRS score in body' do
      expect(mail.body.encoded).to include('75.0%')
    end

    it 'includes link to admin dashboard' do
      expect(mail.body.encoded).to include('http://example.com/admin/1')
    end

    it 'mentions churn risk' do
      expect(mail.body.encoded).to match(/churn risk/i)
    end
  end
end

