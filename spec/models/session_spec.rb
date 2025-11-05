require 'rails_helper'

RSpec.describe Session, type: :model do
  let(:tutor) { Tutor.create!(name: 'John Doe', email: 'john@example.com') }
  let(:student) { Student.create!(name: 'Jane Smith', email: 'jane@example.com') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      session = Session.new(
        tutor: tutor,
        student: student,
        scheduled_start_at: 1.hour.ago,
        actual_start_at: 1.hour.ago,
        scheduled_end_at: Time.current,
        actual_end_at: Time.current,
        status: 'completed',
        reschedule_initiator: 'student',
        tech_issue: false,
        first_session_for_student: true
      )
      expect(session).to be_valid
    end

    it 'requires a tutor' do
      session = Session.new(student: student)
      expect(session).not_to be_valid
      expect(session.errors[:tutor]).to include("must exist")
    end

    it 'requires a student' do
      session = Session.new(tutor: tutor)
      expect(session).not_to be_valid
      expect(session.errors[:student]).to include("must exist")
    end
  end

  describe 'associations' do
    it 'belongs to a tutor' do
      expect(Session.reflect_on_association(:tutor)).not_to be_nil
    end

    it 'belongs to a student' do
      expect(Session.reflect_on_association(:student)).not_to be_nil
    end

    it 'has one session transcript' do
      expect(Session.reflect_on_association(:session_transcript)).not_to be_nil
    end
  end

  describe 'fields' do
    it 'has scheduled_start_at' do
      session = Session.new(tutor: tutor, student: student, scheduled_start_at: 1.hour.ago)
      expect(session.scheduled_start_at).to be_present
    end

    it 'has actual_start_at' do
      session = Session.new(tutor: tutor, student: student, actual_start_at: 1.hour.ago)
      expect(session.actual_start_at).to be_present
    end

    it 'has scheduled_end_at' do
      session = Session.new(tutor: tutor, student: student, scheduled_end_at: Time.current)
      expect(session.scheduled_end_at).to be_present
    end

    it 'has actual_end_at' do
      session = Session.new(tutor: tutor, student: student, actual_end_at: Time.current)
      expect(session.actual_end_at).to be_present
    end

    it 'has status' do
      session = Session.new(tutor: tutor, student: student, status: 'completed')
      expect(session.status).to eq('completed')
    end

    it 'has reschedule_initiator' do
      session = Session.new(tutor: tutor, student: student, reschedule_initiator: 'tutor')
      expect(session.reschedule_initiator).to eq('tutor')
    end

    it 'has tech_issue boolean' do
      session = Session.new(tutor: tutor, student: student, tech_issue: true)
      expect(session.tech_issue).to be true
    end

    it 'has first_session_for_student boolean' do
      session = Session.new(tutor: tutor, student: student, first_session_for_student: true)
      expect(session.first_session_for_student).to be true
    end
  end
end
