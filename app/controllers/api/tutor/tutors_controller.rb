module Api
  module Tutor
    class TutorsController < ApplicationController
      def fsrs_latest
        tutor = ::Tutor.find_by(id: params[:id])
        return render json: { error: 'Tutor not found' }, status: :not_found unless tutor

        fsrs_score = ::Score.where(tutor: tutor, score_type: 'fsrs')
                         .order(computed_at: :desc)
                         .first

        return render json: { error: 'No FSRS score found' }, status: :not_found unless fsrs_score

        render json: {
          score: fsrs_score.value.to_f,
          feedback: fsrs_score.components['feedback'] || fsrs_score.components[:feedback] || {},
          session_id: fsrs_score.session_id,
          computed_at: fsrs_score.computed_at
        }
      end

      def fsrs_history
        tutor = ::Tutor.find_by(id: params[:id])
        return render json: { error: 'Tutor not found' }, status: :not_found unless tutor

        fsrs_scores = ::Score.where(tutor: tutor, score_type: 'fsrs')
                          .includes(:session)
                          .order(computed_at: :desc)
                          .limit(5)

        history = fsrs_scores.map do |score|
          {
            score: score.value.to_f,
            session_id: score.session_id,
            student_name: score.session&.student&.name,
            date: score.session&.scheduled_start_at,
            computed_at: score.computed_at,
            feedback: score.components['feedback'] || score.components[:feedback] || {}
          }
        end

        render json: history
      end

      def performance_summary
        tutor = ::Tutor.find_by(id: params[:id])
        return render json: { error: 'Tutor not found' }, status: :not_found unless tutor

        # Use PerformanceSummaryService for intelligent, trend-based summaries
        service = PerformanceSummaryService.new(tutor)
        summary_data = service.generate_summary

        render json: summary_data
      end

      def session_list
        tutor = ::Tutor.find_by(id: params[:id])
        return render json: { error: 'Tutor not found' }, status: :not_found unless tutor

        sessions = ::Session.where(tutor: tutor, status: 'completed')
                        .includes(:student, :scores)
                        .order(scheduled_start_at: :desc)
                        .limit(20)

        session_list = sessions.map do |session|
          sqs_score = session.scores.find { |s| s.score_type == 'sqs' }
          fsrs_score = session.scores.find { |s| s.score_type == 'fsrs' }

          {
            id: session.id,
            date: session.scheduled_start_at,
            student_name: session.student.name,
            sqs: sqs_score&.value&.to_f,
            sqs_label: sqs_score&.components&.dig('label') || sqs_score&.components&.dig(:label),
            fsrs: fsrs_score&.value&.to_f,
            first_session: session.first_session_for_student
          }
        end

        render json: session_list
      end
    end
  end
end

