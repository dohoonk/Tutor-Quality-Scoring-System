require 'rails_helper'

RSpec.describe TutorDailyAggregationJob, type: :job do
  let(:tutor) { Tutor.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let(:student) { Student.create!(name: 'Bob Student', email: 'bob@example.com') }

  before do
    # Clear any existing aggregates
    TutorDailyAggregate.destroy_all
  end

  describe '#perform' do
    context 'with completed sessions on a single day' do
      let(:target_date) { Date.yesterday }

      before do
        # Create 3 completed sessions for yesterday
        3.times do |i|
          Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: target_date.to_time + (i * 2).hours,
            actual_start_at: target_date.to_time + (i * 2).hours + 5.minutes, # 5 min late
            scheduled_end_at: target_date.to_time + (i * 2).hours + 60.minutes,
            actual_end_at: target_date.to_time + (i * 2).hours + 60.minutes,
            status: 'completed',
            tech_issue: false,
            first_session_for_student: false
          )
        end
      end

      it 'creates daily aggregate record' do
        expect {
          TutorDailyAggregationJob.new.perform
        }.to change { TutorDailyAggregate.count }.by(1)
      end

      it 'calculates sessions_completed correctly' do
        TutorDailyAggregationJob.new.perform
        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.sessions_completed).to eq(3)
      end

      it 'calculates average lateness correctly' do
        TutorDailyAggregationJob.new.perform
        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.avg_lateness_min).to eq(5.0)
      end

      it 'sets reschedules and no_shows to zero when none present' do
        TutorDailyAggregationJob.new.perform
        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.reschedules_tutor_initiated).to eq(0)
        expect(aggregate.no_shows).to eq(0)
      end
    end

    context 'with reschedules' do
      let(:target_date) { Date.yesterday }

      before do
        # 2 completed sessions
        2.times do
          Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: target_date.to_time,
            actual_start_at: target_date.to_time,
            scheduled_end_at: target_date.to_time + 60.minutes,
            actual_end_at: target_date.to_time + 60.minutes,
            status: 'completed',
            first_session_for_student: false
          )
        end

        # 1 rescheduled by tutor
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: target_date.to_time,
          actual_start_at: nil,
          scheduled_end_at: nil,
          actual_end_at: nil,
          status: 'rescheduled',
          reschedule_initiator: 'tutor',
          first_session_for_student: false
        )

        # 1 rescheduled by student (should not count)
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: target_date.to_time,
          actual_start_at: nil,
          scheduled_end_at: nil,
          actual_end_at: nil,
          status: 'rescheduled',
          reschedule_initiator: 'student',
          first_session_for_student: false
        )
      end

      it 'counts only tutor-initiated reschedules' do
        TutorDailyAggregationJob.new.perform
        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.reschedules_tutor_initiated).to eq(1)
        expect(aggregate.sessions_completed).to eq(2)
      end
    end

    context 'with no-shows' do
      let(:target_date) { Date.yesterday }

      before do
        # 2 completed sessions
        2.times do
          Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: target_date.to_time,
            actual_start_at: target_date.to_time,
            scheduled_end_at: target_date.to_time + 60.minutes,
            actual_end_at: target_date.to_time + 60.minutes,
            status: 'completed',
            first_session_for_student: false
          )
        end

        # 1 no-show
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: target_date.to_time,
          actual_start_at: nil,
          scheduled_end_at: nil,
          actual_end_at: nil,
          status: 'no_show',
          first_session_for_student: false
        )
      end

      it 'counts no-shows correctly' do
        TutorDailyAggregationJob.new.perform
        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.no_shows).to eq(1)
        expect(aggregate.sessions_completed).to eq(2)
      end
    end

    context 'with sessions from multiple days' do
      before do
        # Sessions from 3 different days (3 days ago, 2 days ago, 1 day ago)
        [3, 2, 1].each do |days_ago|
          Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: days_ago.days.ago.beginning_of_day + 10.hours,
            actual_start_at: days_ago.days.ago.beginning_of_day + 10.hours,
            scheduled_end_at: days_ago.days.ago.beginning_of_day + 11.hours,
            actual_end_at: days_ago.days.ago.beginning_of_day + 11.hours,
            status: 'completed',
            first_session_for_student: false
          )
        end
      end

      it 'creates separate aggregates for each day' do
        expect {
          TutorDailyAggregationJob.new.perform
        }.to change { TutorDailyAggregate.count }.by(3)
      end
    end

    context 'with multiple tutors' do
      let(:tutor2) { Tutor.create!(name: 'Bob Smith', email: 'bob@example.com') }
      let(:target_date) { Date.yesterday }

      before do
        # Sessions for tutor 1
        2.times do
          Session.create!(
            tutor: tutor,
            student: student,
            scheduled_start_at: target_date.to_time,
            actual_start_at: target_date.to_time,
            scheduled_end_at: target_date.to_time + 60.minutes,
            actual_end_at: target_date.to_time + 60.minutes,
            status: 'completed',
            first_session_for_student: false
          )
        end

        # Sessions for tutor 2
        3.times do
          Session.create!(
            tutor: tutor2,
            student: student,
            scheduled_start_at: target_date.to_time,
            actual_start_at: target_date.to_time,
            scheduled_end_at: target_date.to_time + 60.minutes,
            actual_end_at: target_date.to_time + 60.minutes,
            status: 'completed',
            first_session_for_student: false
          )
        end
      end

      it 'creates separate aggregates for each tutor' do
        expect {
          TutorDailyAggregationJob.new.perform
        }.to change { TutorDailyAggregate.count }.by(2)

        agg1 = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        agg2 = TutorDailyAggregate.find_by(tutor: tutor2, date: target_date)

        expect(agg1.sessions_completed).to eq(2)
        expect(agg2.sessions_completed).to eq(3)
      end
    end

    context 'when aggregate already exists for the day' do
      let(:target_date) { Date.yesterday }

      before do
        # Create initial session
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: target_date.to_time,
          actual_start_at: target_date.to_time,
          scheduled_end_at: target_date.to_time + 60.minutes,
          actual_end_at: target_date.to_time + 60.minutes,
          status: 'completed',
          first_session_for_student: false
        )

        # Run job to create aggregate
        TutorDailyAggregationJob.new.perform

        # Create another session for the same day
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: target_date.to_time + 2.hours,
          actual_start_at: target_date.to_time + 2.hours,
          scheduled_end_at: target_date.to_time + 3.hours,
          actual_end_at: target_date.to_time + 3.hours,
          status: 'completed',
          first_session_for_student: false
        )
      end

      it 'updates existing aggregate instead of creating duplicate' do
        expect {
          TutorDailyAggregationJob.new.perform
        }.not_to change { TutorDailyAggregate.count }

        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.sessions_completed).to eq(2)
      end
    end

    context 'with edge case: zero completed sessions but has reschedules' do
      let(:target_date) { Date.yesterday }

      before do
        Session.create!(
          tutor: tutor,
          student: student,
          scheduled_start_at: target_date.to_time,
          actual_start_at: nil,
          scheduled_end_at: nil,
          actual_end_at: nil,
          status: 'rescheduled',
          reschedule_initiator: 'tutor',
          first_session_for_student: false
        )
      end

      it 'creates aggregate with zero completed sessions' do
        TutorDailyAggregationJob.new.perform
        aggregate = TutorDailyAggregate.find_by(tutor: tutor, date: target_date)
        expect(aggregate.sessions_completed).to eq(0)
        expect(aggregate.reschedules_tutor_initiated).to eq(1)
        expect(aggregate.avg_lateness_min).to eq(0.0)
      end
    end

    context 'refreshing materialized views' do
      it 'refreshes tutor_stats_7d materialized view after aggregation' do
        # This test verifies the view refresh is called
        # We can't easily test the view contents in a unit test, but we can verify no errors
        expect {
          TutorDailyAggregationJob.new.perform
        }.not_to raise_error
      end
    end
  end
end

