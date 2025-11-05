# frozen_string_literal: true

module Api
  module Admin
    module Tutors
      class TutorsController < ApplicationController
        def risk_list
          tutors = ::Tutor.all.map do |tutor|
            # Get latest scores for each type
            latest_fsqs = tutor.scores.where(score_type: 'fsqs').order(computed_at: :desc).first
            latest_ths = tutor.scores.where(score_type: 'ths').order(computed_at: :desc).first
            latest_tcrs = tutor.scores.where(score_type: 'tcrs').order(computed_at: :desc).first

            # Count open alerts
            alert_count = tutor.alerts.where(status: 'open').count

            {
              id: tutor.id,
              name: tutor.name,
              email: tutor.email,
              fsqs: latest_fsqs&.value&.to_f,
              ths: latest_ths&.value&.to_f,
              tcrs: latest_tcrs&.value&.to_f,
              alert_count: alert_count
            }
          end

          # Sort by risk: prioritize tutors with low FSQS, low THS, high TCRS
          # Tutors with nil scores are considered potential risks
          tutors_sorted = tutors.sort_by do |t|
            risk_score = 0

            # FSQS: lower is worse (≤50 is risk), higher is better - invert it for risk calculation
            risk_score += (100 - (t[:fsqs] || 70)) # nil treated as medium risk

            # THS: lower is worse (< 55 is high risk)
            risk_score += (100 - (t[:ths] || 65)) # nil treated as medium risk

            # TCRS: higher is worse (>= 0.6 is risk)
            risk_score += ((t[:tcrs] || 0.4) * 100) # nil treated as medium risk

            # Alert count adds to risk
            risk_score += (t[:alert_count] * 20)

            -risk_score # Negative for descending sort (highest risk first)
          end

          render json: tutors_sorted
        end
      end
    end
  end
end

