# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin API', type: :request do
  describe 'GET /api/admin/tutors/risk_list' do
    let!(:tutor1) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
    let!(:tutor2) { Tutor.create!(name: 'Bob Jones', email: 'bob@example.com') }
    let!(:tutor3) { Tutor.create!(name: 'Charlie Brown', email: 'charlie@example.com') }

    before do
      # Create FSRS scores (first session risk)
      Score.create!(
        tutor: tutor1,
        session: nil,
        score_type: 'fsrs',
        value: 55.0, # High risk
        computed_at: 1.day.ago
      )
      
      Score.create!(
        tutor: tutor2,
        session: nil,
        score_type: 'fsrs',
        value: 20.0, # Good
        computed_at: 1.day.ago
      )

      # Create THS scores (tutor health)
      Score.create!(
        tutor: tutor1,
        session: nil,
        score_type: 'ths',
        value: 45.0, # High risk
        computed_at: 1.day.ago
      )
      
      Score.create!(
        tutor: tutor2,
        session: nil,
        score_type: 'ths',
        value: 80.0, # Stable
        computed_at: 1.day.ago
      )

      # Create TCRS scores (churn risk)
      Score.create!(
        tutor: tutor1,
        session: nil,
        score_type: 'tcrs',
        value: 0.7, # High churn risk
        computed_at: 1.day.ago
      )
      
      Score.create!(
        tutor: tutor2,
        session: nil,
        score_type: 'tcrs',
        value: 0.2, # Stable
        computed_at: 1.day.ago
      )

      # Tutor3 has no scores
    end

    it 'returns list of tutors with their latest risk scores' do
      get '/api/admin/tutors/risk_list'

      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(3)

      # Check tutor1 (high risk)
      tutor1_data = json.find { |t| t['id'] == tutor1.id }
      expect(tutor1_data).to include(
        'name' => 'Alice Smith',
        'fsrs' => 55.0,
        'ths' => 45.0,
        'tcrs' => 0.7
      )

      # Check tutor2 (stable)
      tutor2_data = json.find { |t| t['id'] == tutor2.id }
      expect(tutor2_data).to include(
        'name' => 'Bob Jones',
        'fsrs' => 20.0,
        'ths' => 80.0,
        'tcrs' => 0.2
      )

      # Check tutor3 (no scores)
      tutor3_data = json.find { |t| t['id'] == tutor3.id }
      expect(tutor3_data).to include(
        'name' => 'Charlie Brown',
        'fsrs' => nil,
        'ths' => nil,
        'tcrs' => nil
      )
    end

    it 'sorts tutors by highest risk (FSRS, THS, TCRS combined)' do
      get '/api/admin/tutors/risk_list'

      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      
      # tutor1 should be first (has high FSRS, low THS, high TCRS)
      # tutor3 should be second (no data = potential risk)
      # tutor2 should be last (all stable)
      expect(json[0]['id']).to eq(tutor1.id)
      expect(json[2]['id']).to eq(tutor2.id)
    end

    it 'includes alert count for each tutor' do
      # Create alerts for tutor1
      Alert.create!(tutor: tutor1, alert_type: 'poor_first_session', severity: 'high', status: 'open', triggered_at: Time.current)
      Alert.create!(tutor: tutor1, alert_type: 'high_reliability_risk', severity: 'high', status: 'open', triggered_at: Time.current)

      get '/api/admin/tutors/risk_list'

      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      tutor1_data = json.find { |t| t['id'] == tutor1.id }
      
      expect(tutor1_data['alert_count']).to eq(2)
    end

    it 'handles tutors with only some scores' do
      # Create a tutor with only FSRS score
      tutor4 = Tutor.create!(name: 'Diana Prince', email: 'diana@example.com')
      Score.create!(
        tutor: tutor4,
        session: nil,
        score_type: 'fsrs',
        value: 40.0,
        computed_at: 1.day.ago
      )

      get '/api/admin/tutors/risk_list'

      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      tutor4_data = json.find { |t| t['id'] == tutor4.id }
      
      expect(tutor4_data).to include(
        'fsrs' => 40.0,
        'ths' => nil,
        'tcrs' => nil
      )
    end
  end

  describe 'GET /api/admin/tutor/:id/metrics' do
    let!(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
    
    it 'returns full metrics breakdown for a tutor' do
      # TODO: Will implement after defining metrics structure
      get "/api/admin/tutor/#{tutor.id}/metrics"
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/admin/tutor/:id/fsrs_history' do
    let!(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
    
    it 'returns FSRS history for a tutor' do
      # TODO: Will implement after defining FSRS history structure
      get "/api/admin/tutor/#{tutor.id}/fsrs_history"
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/admin/tutor/:id/intervention_log' do
    let!(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
    
    it 'returns past interventions for a tutor' do
      # TODO: Will implement after defining intervention log structure
      get "/api/admin/tutor/#{tutor.id}/intervention_log"
      
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/admin/alerts/:id/update_status' do
    let!(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
    let!(:alert) { Alert.create!(tutor: tutor, alert_type: 'poor_first_session', severity: 'high', status: 'open', triggered_at: Time.current) }
    
    it 'updates alert status' do
      # TODO: Will implement after defining alert update structure
      post "/api/admin/alerts/#{alert.id}/update_status", params: { status: 'acknowledged' }
      
      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      expect(json['status']).to eq('acknowledged')
    end
  end
end

