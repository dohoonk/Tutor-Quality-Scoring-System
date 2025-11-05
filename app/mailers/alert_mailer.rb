class AlertMailer < ApplicationMailer
  default from: 'noreply@tutor-insights.com'

  def low_first_session_quality_alert(alert, admin_email)
    @alert = alert
    @tutor = alert.tutor
    @fsqs_score = alert.metadata['score_value']
    @score_components = alert.metadata['score_components'] || {}
    @admin_dashboard_url = admin_dashboard_url

    mail(
      to: admin_email,
      subject: '🚨 Alert: Low First Session Quality Detected'
    )
  end

  def high_reliability_risk_alert(alert, admin_email)
    @alert = alert
    @tutor = alert.tutor
    @ths_score = alert.metadata['score_value']
    @admin_dashboard_url = admin_dashboard_url

    mail(
      to: admin_email,
      subject: '⚠️ Alert: High Reliability Risk Detected'
    )
  end

  def churn_risk_alert(alert, admin_email)
    @alert = alert
    @tutor = alert.tutor
    @tcrs_score = alert.metadata['score_value']
    @admin_dashboard_url = admin_dashboard_url

    mail(
      to: admin_email,
      subject: '🚨 Alert: Tutor Churn Risk Detected'
    )
  end

  private

  def admin_dashboard_url
    host = ActionMailer::Base.default_url_options[:host]
    port = ActionMailer::Base.default_url_options[:port]
    base_url = port && port != 80 && port != 443 ? "http://#{host}:#{port}" : "http://#{host}"
    "#{base_url}/admin/1"
  end
end

