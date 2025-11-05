require 'rails_helper'

RSpec.describe AlertJob, type: :job do
  describe '#perform' do
    it 'calls AlertService to evaluate all tutors' do
      tutor1 = Tutor.create!(name: 'Tutor 1', email: 'tutor1@example.com')
      tutor2 = Tutor.create!(name: 'Tutor 2', email: 'tutor2@example.com')

      Score.create!(
        session: nil,
        tutor: tutor1,
        score_type: 'fsrs',
        value: 55,
        components: { score: 55 },
        computed_at: Time.current
      )
      Score.create!(
        session: nil,
        tutor: tutor2,
        score_type: 'ths',
        value: 50,
        components: { score: 50 },
        computed_at: Time.current
      )

      expect_any_instance_of(AlertService).to receive(:evaluate_all_tutors).and_call_original

      AlertJob.perform_now

      expect(Alert.where(tutor: tutor1).count).to eq(1)
      expect(Alert.where(tutor: tutor2).count).to eq(1)
    end

    it 'handles errors gracefully' do
      allow_any_instance_of(AlertService).to receive(:evaluate_all_tutors).and_raise(StandardError, 'Test error')

      expect { AlertJob.perform_now }.not_to raise_error
    end
  end
end

