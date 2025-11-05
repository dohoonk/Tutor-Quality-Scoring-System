class AlertService
  def evaluate_and_create_alerts(tutor)
    # Get latest scores for this tutor
    latest_fsqs = Score.where(tutor: tutor, score_type: 'fsqs').order(computed_at: :desc).first
    latest_ths = Score.where(tutor: tutor, score_type: 'ths').order(computed_at: :desc).first
    latest_tcrs = Score.where(tutor: tutor, score_type: 'tcrs').order(computed_at: :desc).first

    # Check FSQS threshold (≤ 50 indicates low quality, inverted scoring: higher is better)
    if latest_fsqs && latest_fsqs.value <= 50
      handle_alert(tutor, 'low_first_session_quality', 'high', latest_fsqs)
    else
      resolve_alert_if_exists(tutor, 'low_first_session_quality')
    end

    # Check THS threshold (< 55)
    if latest_ths && latest_ths.value < 55
      handle_alert(tutor, 'high_reliability_risk', 'high', latest_ths)
    else
      resolve_alert_if_exists(tutor, 'high_reliability_risk')
    end

    # Check TCRS threshold (≥ 0.6)
    if latest_tcrs && latest_tcrs.value >= 0.6
      handle_alert(tutor, 'churn_risk', 'high', latest_tcrs)
    else
      resolve_alert_if_exists(tutor, 'churn_risk')
    end
  end

  def evaluate_all_tutors
    Tutor.find_each do |tutor|
      evaluate_and_create_alerts(tutor)
    end
  end

  private

  def handle_alert(tutor, alert_type, severity, score)
    # Check if alert already exists
    existing_alert = Alert.find_by(
      tutor: tutor,
      alert_type: alert_type,
      status: 'open'
    )

    if existing_alert
      # Alert already exists - update metadata but don't create duplicate
      existing_alert.update!(
        metadata: existing_alert.metadata.merge(
          last_checked_at: Time.current,
          score_value: score.value,
          score_computed_at: score.computed_at
        )
      )
    else
      # Create new alert
      alert = Alert.create!(
        tutor: tutor,
        alert_type: alert_type,
        severity: severity,
        status: 'open',
        triggered_at: Time.current,
        metadata: {
          score_value: score.value,
          score_computed_at: score.computed_at,
          score_components: score.components
        }
      )
      
      # Send email notification for new alert
      send_alert_email(alert)
    end
  end
  
  def send_alert_email(alert)
    # Get admin email from ENV or use default
    admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
    
    # Send appropriate email based on alert type
    case alert.alert_type
    when 'low_first_session_quality'
      AlertMailer.low_first_session_quality_alert(alert, admin_email).deliver_later
    when 'high_reliability_risk'
      AlertMailer.high_reliability_risk_alert(alert, admin_email).deliver_later
    when 'churn_risk'
      AlertMailer.churn_risk_alert(alert, admin_email).deliver_later
    end
  rescue StandardError => e
    # Log error but don't fail the alert creation
    Rails.logger.error "Failed to send alert email: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def resolve_alert_if_exists(tutor, alert_type)
    alert = Alert.find_by(
      tutor: tutor,
      alert_type: alert_type,
      status: 'open'
    )

    if alert
      alert.update!(
        status: 'resolved',
        resolved_at: Time.current,
        metadata: alert.metadata.merge(
          resolved_at: Time.current,
          auto_resolved: true
        )
      )
    end
  end
end

