require 'rails_helper'

RSpec.describe 'Tutor API', type: :request do
  let(:tutor) { Tutor.create!(name: 'Test Tutor', email: 'tutor@example.com') }
  let(:student) { Student.create!(name: 'Test Student', email: 'student@example.com') }

  describe 'GET /api/tutor/:id/fsrs_latest' do
    context 'when tutor has FSRS scores' do
      it 'returns the most recent FSRS with feedback' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'What are your goals?', 'words' => 4 },
            { 'speaker' => 'student', 'text' => 'I want to learn', 'words' => 4 },
            { 'speaker' => 'tutor', 'text' => 'Great! Let us summarize what we covered', 'words' => 7 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        # Create FSRS score
        fsrs_score = Score.create!(
          session: session,
          tutor: tutor,
          score_type: 'fsrs',
          value: 15,
          components: {
            score: 15,
            confusion_phrases: 0,
            word_share_imbalance: 0,
            missing_goal_setting: 0,
            missing_encouragement: 0,
            negative_phrasing: 0,
            missing_closing_summary: 0,
            tech_lateness_disruption: 0,
            feedback: {
              'what_went_well' => 'Good session',
              'improvement_idea' => 'Keep it up'
            }
          },
          computed_at: Time.current
        )

        get "/api/tutor/#{tutor.id}/fsrs_latest"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['score']).to eq(15.0)
        expect(json['feedback']['what_went_well']).to eq('Good session')
        expect(json['feedback']['improvement_idea']).to eq('Keep it up')
        expect(json['session_id']).to eq(session.id)
        expect(json['computed_at']).to be_present
      end
    end

    context 'when tutor has no FSRS scores' do
      it 'returns 404' do
        get "/api/tutor/#{tutor.id}/fsrs_latest"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when tutor does not exist' do
      it 'returns 404' do
        get "/api/tutor/99999/fsrs_latest"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/tutor/:id/fsrs_history' do
    it 'returns last 5 first-sessions with FSRS' do
      # Create multiple sessions with FSRS scores
      6.times do |i|
        student = Student.create!(name: "Student #{i}", email: "student#{i}@example.com")
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: i.days.ago,
          actual_start_at: i.days.ago,
          scheduled_end_at: i.days.ago + 1.hour,
          actual_end_at: i.days.ago + 1.hour,
          status: 'completed',
          first_session_for_student: true
        )

        Score.create!(
          session: session,
          tutor: tutor,
          score_type: 'fsrs',
          value: 10 + i,
          components: { score: 10 + i },
          computed_at: i.days.ago
        )
      end

      get "/api/tutor/#{tutor.id}/fsrs_history"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(5) # Only last 5
      expect(json.first['score']).to eq(10.0) # Most recent (i=0, so 10+0=10)
      expect(json.last['score']).to eq(14.0) # Oldest of the 5 (i=4, so 10+4=14)
    end

    it 'returns empty array when no FSRS scores exist' do
      get "/api/tutor/#{tutor.id}/fsrs_history"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe 'GET /api/tutor/:id/performance_summary' do
    it 'returns performance summary' do
      # Create some SQS scores
      5.times do |i|
        student = Student.create!(name: "Student #{i}", email: "student#{i}@example.com")
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: i.days.ago,
          actual_start_at: i.days.ago,
          scheduled_end_at: i.days.ago + 1.hour,
          actual_end_at: i.days.ago + 1.hour,
          status: 'completed'
        )

        Score.create!(
          session: session,
          tutor: tutor,
          score_type: 'sqs',
          value: 70 + i,
          components: { score: 70 + i },
          computed_at: i.days.ago
        )
      end

      get "/api/tutor/#{tutor.id}/performance_summary"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['summary']).to be_present
      expect(json['summary']).to be_a(String)
    end
  end

  describe 'GET /api/tutor/:id/session_list' do
    it 'returns recent sessions with SQS values' do
      # Create sessions with SQS scores
      3.times do |i|
        student = Student.create!(name: "Student #{i}", email: "student#{i}@example.com")
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: i.days.ago,
          actual_start_at: i.days.ago,
          scheduled_end_at: i.days.ago + 1.hour,
          actual_end_at: i.days.ago + 1.hour,
          status: 'completed'
        )

        Score.create!(
          session: session,
          tutor: tutor,
          score_type: 'sqs',
          value: 75 + i,
          components: { score: 75 + i, label: 'ok' },
          computed_at: i.days.ago
        )
      end

      get "/api/tutor/#{tutor.id}/session_list"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(3)
      expect(json.first['sqs']).to eq(75.0) # Most recent (i=0, so 75+0=75)
      expect(json.first['student_name']).to be_present
      expect(json.first['date']).to be_present
    end

    it 'returns empty array when no sessions exist' do
      get "/api/tutor/#{tutor.id}/session_list"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end
end

