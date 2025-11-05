# Email Notifications - Tutor Quality Scoring System

This document describes the email notification system for alerting admins/coaches when tutors require intervention.

## Overview

The system automatically sends email notifications when high-risk alerts are triggered for tutors. Emails are sent immediately when a new alert is created (not for duplicate/existing alerts).

## How It Works

### 1. Alert Triggers

Alerts are evaluated every 10 minutes by the `AlertJob`:

| Alert Type | Trigger Condition | Severity |
|-----------|------------------|----------|
| Poor First Session | FSQS ≥ 50 | High |
| High Reliability Risk | THS < 55 | High |
| Churn Risk | TCRS ≥ 0.6 | High |

### 2. Email Delivery

- **New Alerts:** When an alert is first triggered, an email is sent immediately via `deliver_later` (uses Sidekiq background jobs)
- **Existing Alerts:** No duplicate emails sent if alert already exists
- **Resolved Alerts:** No emails sent when alerts auto-resolve

### 3. Email Templates

Each alert type has its own professionally designed email template:

- **Poor First Session Alert** (`low_first_session_quality_alert`)
  - Subject: "🚨 Alert: Poor First Session Detected"
  - Includes: FSQS score, score breakdown, recommended actions
  
- **High Reliability Risk Alert** (`high_reliability_risk_alert`)
  - Subject: "⚠️ Alert: High Reliability Risk Detected"
  - Includes: THS score, reliability concerns, action steps
  
- **Churn Risk Alert** (`churn_risk_alert`)
  - Subject: "🚨 Alert: Tutor Churn Risk Detected"
  - Includes: TCRS score, disengagement patterns, urgent actions

All emails include:
- Tutor name and email
- Alert timestamp
- Specific score with context
- Recommended actions
- Link to admin dashboard
- Both HTML and plain text versions

## Configuration

### Development Environment

**Delivery Method:** `letter_opener` (opens emails in browser)

No additional configuration needed. When an alert is triggered in development:
1. Email is queued via Sidekiq
2. Email opens automatically in your default browser
3. View all sent emails in `/tmp/letter_opener/`

**Test emails in development:**
```bash
# In Rails console
rails console

# Trigger an alert manually
tutor = Tutor.first
alert = Alert.create!(
  tutor: tutor,
  alert_type: 'low_first_session_quality',
  severity: 'high',
  status: 'open',
  triggered_at: Time.current,
  metadata: { score_value: 55.0 }
)

# Manually send email (normally automatic)
AlertMailer.low_first_session_quality_alert(alert, 'test@example.com').deliver_now
```

The email will open in your browser via `letter_opener`.

### Production Environment

**Delivery Method:** SMTP

**Required Environment Variables:**

```bash
# Admin Email - who receives alerts
ADMIN_EMAIL=admin@yourcompany.com

# SMTP Settings (example: SendGrid)
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER_NAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
SMTP_DOMAIN=yourcompany.com
MAILER_HOST=your-production-domain.com
```

**Supported SMTP Providers:**
- SendGrid (recommended)
- Mailgun
- Amazon SES
- Postmark
- Any SMTP-compliant service

**SendGrid Setup Example:**
1. Create SendGrid account
2. Generate API key
3. Set `SMTP_USER_NAME=apikey`
4. Set `SMTP_PASSWORD=<your_api_key>`
5. Verify sender identity in SendGrid
6. Update `ADMIN_EMAIL` to verified address

**Testing Production Config (Staging):**
```bash
# Set environment variables
export ADMIN_EMAIL=your-email@example.com
export SMTP_ADDRESS=smtp.sendgrid.net
export SMTP_PORT=587
export SMTP_USER_NAME=apikey
export SMTP_PASSWORD=your_sendgrid_api_key
export SMTP_DOMAIN=yourcompany.com
export MAILER_HOST=staging.yourcompany.com

# Start Rails in production mode
RAILS_ENV=production rails server

# Trigger test alert
RAILS_ENV=production rails runner "
  tutor = Tutor.first
  AlertService.new.evaluate_and_create_alerts(tutor)
"
```

### Test Environment

**Delivery Method:** `test` (captured for assertions)

Emails are captured in `ActionMailer::Base.deliveries` array for testing.

## Email Preferences (Future Enhancement)

Currently, all alerts are sent to a single `ADMIN_EMAIL`. Future enhancements could include:

1. **Multiple Recipients:**
   ```ruby
   # Example: ADMIN_EMAILS=admin1@example.com,admin2@example.com
   admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@example.com').split(',')
   ```

2. **Alert Type Filtering:**
   ```ruby
   # Only send churn risk alerts
   CHURN_ALERT_EMAILS=manager@example.com
   FSQS_ALERT_EMAILS=coach@example.com
   ```

3. **Frequency Settings:**
   - Immediate (current)
   - Daily digest
   - Weekly summary

4. **Severity Filtering:**
   - Only high severity
   - High + medium severity

5. **Unsubscribe Links:**
   - Allow admins to opt-out of specific alert types

## Monitoring & Troubleshooting

### Check Sidekiq Queue

Email delivery is async via Sidekiq:

```bash
# View Sidekiq dashboard
open http://localhost:3000/sidekiq

# Check mailers queue
bundle exec sidekiq
```

### View Email Logs

```bash
# Development (letter_opener)
open /tmp/letter_opener/

# Production logs
tail -f log/production.log | grep "AlertMailer"
```

### Common Issues

**1. Emails not sending in development**
- Check that Sidekiq is running: `bin/dev` or `bundle exec sidekiq`
- Verify letter_opener is installed: `bundle list | grep letter_opener`

**2. Emails not sending in production**
- Verify environment variables are set: `echo $SMTP_ADDRESS`
- Check SMTP credentials are correct
- Review logs: `grep "AlertMailer" log/production.log`
- Test SMTP connection: `telnet $SMTP_ADDRESS $SMTP_PORT`

**3. Duplicate emails**
- This should not happen - alerts prevent duplicates
- If it occurs, check AlertService logic and database constraints

**4. Emails stuck in Sidekiq queue**
- Check Sidekiq is processing jobs: `bundle exec sidekiq`
- View failed jobs: `http://localhost:3000/sidekiq/retries`
- Check for network issues or SMTP errors

### Performance Considerations

- **Email Delivery:** Async via `deliver_later` (doesn't block alert creation)
- **Volume:** At most one email per tutor per alert type per evaluation cycle
- **Rate Limits:** Consider SMTP provider limits (e.g., SendGrid: 100/day free tier)
- **Scaling:** Can add more Sidekiq workers if email volume increases

## Architecture

```
AlertJob (every 10 min)
  ↓
AlertService.evaluate_all_tutors
  ↓
AlertService.handle_alert(tutor, type, severity, score)
  ↓
Alert.create! (new alert)
  ↓
AlertService.send_alert_email(alert)
  ↓
AlertMailer.low_first_session_quality_alert(alert, admin_email).deliver_later
  ↓
Sidekiq (async processing)
  ↓
ActionMailer (SMTP delivery)
  ↓
Admin Inbox ✉️
```

## Security & Privacy

- **PII in Emails:** Tutor names and emails are included (ensure secure email channels)
- **Sensitive Data:** Scores and metadata are included (encrypt emails in transit via STARTTLS)
- **Access Control:** Only configured `ADMIN_EMAIL` receives alerts
- **Audit Trail:** All emails logged in Rails logs

## Testing

**RSpec Tests:**
- `spec/mailers/alert_mailer_spec.rb` - Email content and formatting
- `spec/jobs/alert_job_spec.rb` - Alert creation (includes email triggers)

**Run Tests:**
```bash
bundle exec rspec spec/mailers/alert_mailer_spec.rb
bundle exec rspec spec/jobs/alert_job_spec.rb
```

**Manual Testing:**
```bash
# Development: Trigger alert and view email in browser
rails console
tutor = Tutor.create!(name: 'Test Tutor', email: 'test@example.com')
score = Score.create!(tutor: tutor, score_type: 'fsrs', value: 55.0, computed_at: Time.current)
AlertService.new.evaluate_and_create_alerts(tutor)
# Email opens in browser via letter_opener
```

## Maintenance

### Updating Email Templates

Templates are located in:
- `app/views/alert_mailer/low_first_session_quality_alert.html.erb` (HTML)
- `app/views/alert_mailer/low_first_session_quality_alert.text.erb` (Plain text)
- `app/views/alert_mailer/high_reliability_risk_alert.html.erb`
- `app/views/alert_mailer/high_reliability_risk_alert.text.erb`
- `app/views/alert_mailer/churn_risk_alert.html.erb`
- `app/views/alert_mailer/churn_risk_alert.text.erb`

After updating templates, run tests to verify:
```bash
bundle exec rspec spec/mailers/alert_mailer_spec.rb
```

### Monitoring Email Delivery Rates

Track in production:
1. **Sent Count:** `grep "AlertMailer" log/production.log | wc -l`
2. **Failed Count:** Check Sidekiq retries dashboard
3. **SMTP Metrics:** Review provider dashboard (SendGrid, etc.)

## FAQ

**Q: How often are emails sent?**
A: Only when a NEW alert is triggered. If an alert already exists, no email is sent (prevents spam).

**Q: Can I send alerts to multiple admins?**
A: Currently single recipient via `ADMIN_EMAIL`. See "Email Preferences" section for future enhancements.

**Q: What if SMTP fails?**
A: Sidekiq will retry failed email jobs (default: 25 attempts over ~21 days). The alert is still created and visible in the admin dashboard.

**Q: How do I disable email notifications?**
A: Set `ADMIN_EMAIL=` (empty) or comment out the `send_alert_email` call in `AlertService`.

**Q: Can tutors receive emails about their own alerts?**
A: Not currently. Only admins/coaches receive alerts. Future enhancement could add tutor notifications.

**Q: Are emails GDPR compliant?**
A: Emails contain tutor PII (name, email, performance data). Ensure your email provider and storage comply with GDPR. Consider encryption and retention policies.

## Support

For issues with email delivery:
1. Check Sidekiq dashboard: `http://localhost:3000/sidekiq`
2. Review logs: `tail -f log/development.log | grep AlertMailer`
3. Test SMTP credentials manually
4. Contact SMTP provider support (SendGrid, etc.)

