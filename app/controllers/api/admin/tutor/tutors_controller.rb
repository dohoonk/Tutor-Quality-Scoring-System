# frozen_string_literal: true

module Api
  module Admin
    module Tutor
      class TutorsController < ApplicationController
        def metrics
          tutor = ::Tutor.find(params[:id])
          
          # Get latest scores
          latest_fsqs = tutor.scores.where(score_type: 'fsqs').order(computed_at: :desc).first
          latest_ths = tutor.scores.where(score_type: 'ths').order(computed_at: :desc).first
          latest_tcrs = tutor.scores.where(score_type: 'tcrs').order(computed_at: :desc).first
          
          # Get SQS history (last 10 sessions)
          sqs_history = tutor.scores
            .where(score_type: 'sqs')
            .joins(:session)
            .order('sessions.scheduled_start_at DESC')
            .limit(10)
            .map { |score| { date: score.session.scheduled_start_at, value: score.value.to_f } }
          
          render json: {
            tutor_id: tutor.id,
            name: tutor.name,
            email: tutor.email,
            fsqs: latest_fsqs&.value&.to_f,
            ths: latest_ths&.value&.to_f,
            tcrs: latest_tcrs&.value&.to_f,
            sqs_history: sqs_history
          }
        end

        def fsqs_history
          tutor = ::Tutor.find(params[:id])
          
          # Get all FSQS scores for this tutor
          fsqs_scores = tutor.scores
            .where(score_type: 'fsqs')
            .order(computed_at: :desc)
            .limit(10)
            .map do |score|
              session = score.session
              {
                score: score.value.to_f,
                computed_at: score.computed_at,
                session_id: session&.id,
                session_date: session&.scheduled_start_at,
                student_name: session&.student&.name,
                components: score.components
              }
            end
          
          render json: fsqs_scores
        end

        def intervention_log
          tutor = ::Tutor.find(params[:id])
          
          # Get all resolved alerts (these represent past interventions)
          interventions = tutor.alerts
            .where(status: 'resolved')
            .order(resolved_at: :desc)
            .limit(20)
            .map do |alert|
              {
                id: alert.id,
                alert_type: alert.alert_type,
                severity: alert.severity,
                triggered_at: alert.triggered_at,
                resolved_at: alert.resolved_at,
                metadata: alert.metadata
              }
            end
          
          render json: interventions
        end
      end
    end
  end
end

