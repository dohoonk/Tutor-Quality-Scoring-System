# frozen_string_literal: true

module Api
  module Admin
    module Alerts
      class AlertsController < ApplicationController
        def update_status
          alert = ::Alert.find(params[:id])
          
          # Update alert status
          new_status = params[:status]
          alert.update!(status: new_status)
          
          # If resolved, record resolved_at
          if new_status == 'resolved'
            alert.update!(resolved_at: Time.current)
          end
          
          # Add any notes to metadata
          if params[:notes].present?
            metadata = alert.metadata || {}
            metadata['notes'] ||= []
            metadata['notes'] << {
              text: params[:notes],
              added_at: Time.current,
              added_by: params[:admin_id] || 'admin'
            }
            alert.update!(metadata: metadata)
          end
          
          render json: {
            id: alert.id,
            status: alert.status,
            resolved_at: alert.resolved_at,
            metadata: alert.metadata
          }
        end
      end
    end
  end
end

