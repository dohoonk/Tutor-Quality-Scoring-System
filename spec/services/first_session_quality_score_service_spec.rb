require 'rails_helper'

RSpec.describe FirstSessionQualityScoreService, type: :service do
  let(:tutor) { Tutor.create!(name: 'Test Tutor', email: 'tutor@example.com') }
  let(:student) { Student.create!(name: 'Test Student', email: 'student@example.com') }

  describe '#calculate' do
    context 'when session is not a first session' do
      it 'returns nil' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: false
        )

        result = described_class.new(session).calculate

        expect(result).to be_nil
      end
    end

    context 'when transcript is missing' do
      it 'returns nil' do
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

        result = described_class.new(session).calculate

        expect(result).to be_nil
      end
    end

    context 'when transcript lacks speaker diarization' do
      it 'returns nil' do
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

        SessionTranscript.create!(
          session: session,
          payload: { 'text' => 'Some transcript without speakers' }
        )

        result = described_class.new(session).calculate

        expect(result).to be_nil
      end
    end

    context 'with valid transcript and no risk factors' do
      it 'returns score of 0 with positive feedback' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'Hello! What are your goals for today?', 'words' => 7 },
            { 'speaker' => 'student', 'text' => 'I want to learn math and improve my skills', 'words' => 8 },
            { 'speaker' => 'tutor', 'text' => 'Great! You are doing well. Keep it up!', 'words' => 8 },
            { 'speaker' => 'student', 'text' => 'Thank you for your help', 'words' => 5 },
            { 'speaker' => 'tutor', 'text' => 'Let us summarize what we covered today and plan next steps', 'words' => 12 }
          ],
          'metadata' => { 'total_words_tutor' => 27, 'total_words_student' => 13 }
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result).not_to be_nil
        expect(result[:score]).to eq(0)
        expect(result[:components][:confusion_phrases]).to eq(0)
        expect(result[:components][:word_share_imbalance]).to eq(0)
        expect(result[:components][:missing_goal_setting]).to eq(0)
        expect(result[:components][:missing_encouragement]).to eq(0)
        expect(result[:components][:negative_phrasing]).to eq(0)
        expect(result[:components][:missing_closing_summary]).to eq(0)
        expect(result[:components][:tech_lateness_disruption]).to eq(0)
        expect(result[:feedback]['what_went_well']).to be_present
        expect(result[:feedback]['improvement_idea']).to be_present
      end
    end

    context 'when confusion phrases are detected' do
      it 'adds 20 points for >=3 confusion instances' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'Hello', 'words' => 1 },
            { 'speaker' => 'student', 'text' => 'I do not understand', 'words' => 4 },
            { 'speaker' => 'tutor', 'text' => 'Let me explain', 'words' => 3 },
            { 'speaker' => 'student', 'text' => 'I am confused about this', 'words' => 5 },
            { 'speaker' => 'tutor', 'text' => 'OK', 'words' => 1 },
            { 'speaker' => 'student', 'text' => 'I do not get it', 'words' => 5 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:components][:confusion_phrases]).to eq(20)
        expect(result[:score]).to be >= 20
      end
    end

    context 'when tutor word share is >75%' do
      it 'adds 20 points for word share imbalance' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'Let us talk about many different topics and concepts', 'words' => 10 },
            { 'speaker' => 'student', 'text' => 'OK', 'words' => 1 },
            { 'speaker' => 'tutor', 'text' => 'We will cover algebra geometry and calculus', 'words' => 7 },
            { 'speaker' => 'student', 'text' => 'Yes', 'words' => 1 }
          ],
          'metadata' => { 'total_words_tutor' => 17, 'total_words_student' => 2 }
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        # 17/(17+2) = 89.5% > 75%
        expect(result[:components][:word_share_imbalance]).to eq(20)
        expect(result[:score]).to be >= 20
      end
    end

    context 'when goal-setting is missing' do
      it 'adds 25 points for missing goal-setting question' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'Hello, how are you?', 'words' => 4 },
            { 'speaker' => 'student', 'text' => 'I am fine', 'words' => 3 },
            { 'speaker' => 'tutor', 'text' => 'Let us start working', 'words' => 4 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:components][:missing_goal_setting]).to eq(25)
        expect(result[:score]).to be >= 25
      end
    end

    context 'when encouragement is missing' do
      it 'adds 15 points for missing encouragement phrases' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'What are your goals?', 'words' => 4 },
            { 'speaker' => 'student', 'text' => 'I want to learn', 'words' => 4 },
            { 'speaker' => 'tutor', 'text' => 'OK, let us proceed', 'words' => 4 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:components][:missing_encouragement]).to eq(15)
        expect(result[:score]).to be >= 15
      end
    end

    context 'when negative phrasing is detected' do
      it 'adds 10 points for negative phrasing streak' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'You are wrong', 'words' => 3 },
            { 'speaker' => 'tutor', 'text' => 'That is not correct', 'words' => 4 },
            { 'speaker' => 'tutor', 'text' => 'You failed to understand', 'words' => 4 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:components][:negative_phrasing]).to eq(10)
        expect(result[:score]).to be >= 10
      end
    end

    context 'when closing summary is missing' do
      it 'adds 20 points for missing closing summary' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: false
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'What are your goals?', 'words' => 4 },
            { 'speaker' => 'student', 'text' => 'I want to learn', 'words' => 4 },
            { 'speaker' => 'tutor', 'text' => 'Great, see you later', 'words' => 4 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:components][:missing_closing_summary]).to eq(20)
        expect(result[:score]).to be >= 20
      end
    end

    context 'when tech/lateness disruption is present' do
      it 'adds 10 points for tech issue' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago + 10.minutes, # 10 min late
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: true
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'Hello', 'words' => 1 }
          ]
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:components][:tech_lateness_disruption]).to eq(10)
        expect(result[:score]).to be >= 10
      end
    end

    context 'when all risk factors are present' do
      it 'sums all risk points correctly' do
        session = Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: 1.hour.ago,
          actual_start_at: 1.hour.ago + 5.minutes,
          scheduled_end_at: Time.current,
          actual_end_at: Time.current,
          status: 'completed',
          first_session_for_student: true,
          tech_issue: true
        )

        transcript_payload = {
          'speakers' => [
            { 'speaker' => 'tutor', 'text' => 'Hello', 'words' => 1 },
            { 'speaker' => 'student', 'text' => 'I do not understand', 'words' => 4 },
            { 'speaker' => 'student', 'text' => 'I am confused', 'words' => 3 },
            { 'speaker' => 'student', 'text' => 'I do not get it', 'words' => 5 },
            { 'speaker' => 'tutor', 'text' => 'You are wrong', 'words' => 3 },
            { 'speaker' => 'tutor', 'text' => 'That is incorrect', 'words' => 3 },
            { 'speaker' => 'tutor', 'text' => 'You failed', 'words' => 2 },
            { 'speaker' => 'tutor', 'text' => 'OK bye', 'words' => 2 }
          ],
          'metadata' => { 'total_words_tutor' => 11, 'total_words_student' => 12 }
        }

        SessionTranscript.create!(session: session, payload: transcript_payload)

        result = described_class.new(session).calculate

        expect(result[:score]).to be >= 75 # 20 (confusion) + 0 (word share OK) + 25 (goal) + 15 (encouragement) + 10 (negative) + 20 (summary) + 10 (tech/lateness)
        expect(result[:feedback]['improvement_idea']).to be_present
      end
    end
  end

  describe '#save_score' do
    it 'saves FSRS to scores table' do
      session = Session.create!(
        tutor: tutor,
        student: student,
        scheduled_start_at: 1.hour.ago,
        actual_start_at: 1.hour.ago,
        scheduled_end_at: Time.current,
        actual_end_at: Time.current,
        status: 'completed',
        first_session_for_student: true,
        tech_issue: false
      )

      transcript_payload = {
        'speakers' => [
          { 'speaker' => 'tutor', 'text' => 'What are your goals?', 'words' => 4 },
          { 'speaker' => 'student', 'text' => 'I want to learn', 'words' => 4 },
          { 'speaker' => 'tutor', 'text' => 'Great! You are doing well. Let us summarize what we covered', 'words' => 10 }
        ]
      }

      SessionTranscript.create!(session: session, payload: transcript_payload)

      service = described_class.new(session)
      result = service.calculate
      service.save_score(result) if result

      score = Score.find_by(session: session, score_type: 'fsqs')
      expect(score).to be_present
      expect(score.value).to be >= 0
      expect(score.tutor_id).to eq(tutor.id)
      expect(score.components['score']).to be_present
      expect(score.computed_at).to be_present
    end
  end
end

