# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AIActionableFeedbackService do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let(:student1) { Student.create!(name: 'John Doe', email: 'john@example.com') }
  let(:student2) { Student.create!(name: 'Jane Smith', email: 'jane@example.com') }
  let(:service) { AIActionableFeedbackService.new(tutor, 'encouragement') }

  describe '#generate_feedback' do
    context 'with valid sessions and transcripts' do
      before do
        # Create 5 sessions with transcripts
        5.times do |i|
          session = Session.create!(
            tutor: tutor,
            student: i < 3 ? student1 : student2,
            scheduled_start_at: (5 - i).days.ago,
            actual_start_at: (5 - i).days.ago,
            scheduled_end_at: (5 - i).days.ago + 1.hour,
            actual_end_at: (5 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )

          # Create transcript with speaker diarization
          SessionTranscript.create!(
            session: session,
            payload: {
              'speakers' => [
                { 'speaker' => 'tutor', 'text' => 'Hello! How are you?', 'timestamp' => '00:00:01', 'words' => 4 },
                { 'speaker' => 'student', 'text' => 'I am doing well', 'timestamp' => '00:00:05', 'words' => 4 },
                { 'speaker' => 'tutor', 'text' => 'Let us work on this problem', 'timestamp' => '00:05:00', 'words' => 6 }
              ],
              'metadata' => {
                'duration' => 3600,
                'total_words_tutor' => 100,
                'total_words_student' => 50
              }
            }
          )
        end
      end

      context 'when OpenAI API is available' do
        let(:mock_openai_client) { instance_double(OpenAI::Client) }
        let(:mock_response) do
          {
            'choices' => [
              {
                'message' => {
                  'content' => JSON.generate({
                    moments: [
                      {
                        student_name: 'John Doe',
                        session_date: '2025-11-01',
                        context: 'Student solved problem correctly',
                        suggestion: 'Great job, John! That is exactly right!',
                        reason: 'This would boost confidence at a critical learning moment'
                      }
                    ]
                  })
                }
              }
            ]
          }
        end

        before do
          allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
          allow(mock_openai_client).to receive_message_chain(:chat, :completions).and_return(mock_response)
        end

        it 'fetches last 5 sessions with transcripts' do
          expect(service).to receive(:fetch_sessions).and_call_original
          service.generate_feedback
        end

        it 'calls OpenAI API with correct prompt' do
          expect(mock_openai_client).to receive_message_chain(:chat, :completions)
          service.generate_feedback
        end

        it 'returns structured feedback with moments' do
          result = service.generate_feedback
          expect(result[:moments]).to be_an(Array)
          expect(result[:moments].first).to have_key(:student_name)
          expect(result[:moments].first).to have_key(:suggestion)
        end

        it 'includes actionable item type in response' do
          result = service.generate_feedback
          expect(result[:actionable_item_type]).to eq('encouragement')
        end
      end

      context 'when OpenAI API fails' do
        before do
          allow(OpenAI::Client).to receive(:new).and_raise(StandardError.new('API Error'))
        end

        it 'returns fallback feedback' do
          result = service.generate_feedback
          expect(result[:fallback]).to be(true)
          expect(result[:message]).to be_present
        end
      end

      context 'when rate limit is exceeded' do
        before do
          allow(service).to receive(:check_rate_limit).and_return(false)
        end

        it 'returns rate limit error' do
          result = service.generate_feedback
          expect(result[:error]).to eq('rate_limit_exceeded')
        end
      end
    end

    context 'with insufficient sessions' do
      it 'returns error when fewer than 5 sessions' do
        result = service.generate_feedback
        expect(result[:error]).to eq('insufficient_sessions')
      end
    end

    context 'with sessions missing transcripts' do
      before do
        3.times do |i|
          Session.create!(
            tutor: tutor,
            student: student1,
            scheduled_start_at: (3 - i).days.ago,
            actual_start_at: (3 - i).days.ago,
            scheduled_end_at: (3 - i).days.ago + 1.hour,
            actual_end_at: (3 - i).days.ago + 1.hour,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
        end
      end

      it 'returns error when sessions lack transcripts' do
        result = service.generate_feedback
        expect(result[:error]).to eq('insufficient_sessions')
      end
    end
  end

  describe '#check_rate_limit' do
    it 'allows requests within rate limit' do
      # Clear any existing rate limit entries
      Rails.cache.delete("ai_feedback_rate_limit:tutor:#{tutor.id}")
      
      expect(service.check_rate_limit).to be(true)
    end

    it 'blocks requests exceeding rate limit' do
      # Simulate 5 requests today
      Rails.cache.write("ai_feedback_rate_limit:tutor:#{tutor.id}", 5, expires_in: 1.day)
      
      expect(service.check_rate_limit).to be(false)
    end
  end

  describe '#get_cached_feedback' do
    it 'returns cached feedback if available' do
      cached_data = {
        moments: [{ student_name: 'Test', suggestion: 'Test suggestion' }],
        cached: true
      }
      Rails.cache.write("ai_feedback:tutor:#{tutor.id}:encouragement", cached_data, expires_in: 24.hours)
      
      result = service.get_cached_feedback
      expect(result).to eq(cached_data)
    end

    it 'returns nil if no cache' do
      Rails.cache.delete("ai_feedback:tutor:#{tutor.id}:encouragement")
      expect(service.get_cached_feedback).to be_nil
    end
  end
end

