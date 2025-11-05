class AlertJob < ApplicationJob
  queue_as :default

  def perform
    AlertService.new.evaluate_all_tutors
  rescue StandardError => e
    Rails.logger.error "AlertJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Don't re-raise - we want the job to complete even if some tutors fail
  end
end

