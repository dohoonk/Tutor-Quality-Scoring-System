# frozen_string_literal: true

# Sidekiq Scheduler Initializer
# Loads the schedule configuration from config/sidekiq_schedule.yml

require 'sidekiq-scheduler'

# Load schedule from YAML file
if File.exist?(Rails.root.join('config', 'sidekiq_schedule.yml'))
  schedule_config = YAML.load_file(Rails.root.join('config', 'sidekiq_schedule.yml'))
  
  # Set the schedule
  Sidekiq.configure_server do |config|
    config.on(:startup) do
      Sidekiq.schedule = schedule_config
      SidekiqScheduler::Scheduler.instance.reload_schedule!
      Rails.logger.info "✓ Sidekiq Scheduler initialized with #{schedule_config.keys.count} jobs"
    end
  end
  
  Rails.logger.info "✓ Sidekiq schedule configuration loaded: #{schedule_config.keys.join(', ')}"
else
  Rails.logger.warn "⚠ No sidekiq_schedule.yml file found"
end

