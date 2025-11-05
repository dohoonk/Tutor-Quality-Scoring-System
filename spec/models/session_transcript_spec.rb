require 'rails_helper'

RSpec.describe SessionTranscript, type: :model do
  let(:tutor) { Tutor.create!(name: 'John Doe', email: 'john@example.com') }
  let(:student) { Student.create!(name: 'Jane Smith', email: 'jane@example.com') }
  let(:session) { Session.create!(tutor: tutor, student: student, scheduled_start_at: 1.hour.ago, actual_start_at: 1.hour.ago, scheduled_end_at: Time.current, actual_end_at: Time.current, status: 'completed') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      transcript = SessionTranscript.new(
        session: session,
        payload: { 
          speakers: [
            { speaker: 'tutor', text: 'Hello, how are you?', timestamp: '00:00:01' },
            { speaker: 'student', text: 'I am good, thanks!', timestamp: '00:00:05' }
          ]
        }
      )
      expect(transcript).to be_valid
    end

    it 'requires a session' do
      transcript = SessionTranscript.new(payload: {})
      expect(transcript).not_to be_valid
      expect(transcript.errors[:session]).to include("must exist")
    end

    it 'requires a payload' do
      transcript = SessionTranscript.new(session: session)
      expect(transcript).not_to be_valid
      expect(transcript.errors[:payload]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to a session' do
      expect(SessionTranscript.reflect_on_association(:session)).not_to be_nil
    end
  end

  describe 'payload field' do
    it 'stores JSON data' do
      payload = { 'speakers' => [{ 'speaker' => 'tutor', 'text' => 'Hello' }] }
      transcript = SessionTranscript.new(session: session, payload: payload)
      expect(transcript.payload).to eq(payload)
    end

    it 'can store complex nested JSON structures' do
      payload = {
        'speakers' => [
          { 'speaker' => 'tutor', 'text' => 'Hello', 'timestamp' => '00:00:01', 'words' => 3 },
          { 'speaker' => 'student', 'text' => 'Hi there', 'timestamp' => '00:00:05', 'words' => 2 }
        ],
        'metadata' => { 'duration' => 3600, 'language' => 'en' }
      }
      transcript = SessionTranscript.new(session: session, payload: payload)
      expect(transcript.payload['speakers'].length).to eq(2)
      expect(transcript.payload['metadata']['duration']).to eq(3600)
    end
  end
end
