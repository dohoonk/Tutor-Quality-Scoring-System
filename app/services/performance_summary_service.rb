# frozen_string_literal: true

class PerformanceSummaryService
  CACHE_EXPIRY = 1.hour

  def initialize(tutor)
    @tutor = tutor
  end

  def generate_summary
    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      compute_summary
    end
  end

  # Bust the cache when new scores are added
  def self.bust_cache(tutor_id)
    Rails.cache.delete("performance_summary:tutor:#{tutor_id}")
  end

  private

  def cache_key
    "performance_summary:tutor:#{@tutor.id}"
  end

  def compute_summary
    sqs_scores = fetch_recent_sqs_scores
    
    if sqs_scores.length < 3
      return insufficient_data_summary(sqs_scores)
    end

    trend = analyze_trend(sqs_scores)
    avg_score = calculate_average(sqs_scores)
    
    {
      trend: trend,
      average_sqs: avg_score.round(1),
      summary: generate_summary_text(trend, avg_score, sqs_scores.length),
      what_went_well: generate_what_went_well(avg_score, trend),
      improvement_suggestion: generate_improvement_suggestion(avg_score, trend)
    }
  end

  def fetch_recent_sqs_scores
    @tutor.scores
      .where(score_type: 'sqs')
      .order(computed_at: :desc)
      .limit(5)
      .pluck(:value)
      .map(&:to_f)
  end

  def analyze_trend(scores)
    return :insufficient_data if scores.length < 3

    # Split into two halves and compare averages
    mid_point = scores.length / 2
    recent_half = scores[0...mid_point]
    older_half = scores[mid_point..]

    recent_avg = calculate_average(recent_half)
    older_avg = calculate_average(older_half)

    difference = recent_avg - older_avg

    if difference > 5
      :improving
    elsif difference < -5
      :declining
    else
      :stable
    end
  end

  def calculate_average(scores)
    return 0 if scores.empty?
    scores.sum / scores.length.to_f
  end

  def insufficient_data_summary(scores)
    if scores.empty?
      {
        trend: :insufficient_data,
        average_sqs: nil,
        summary: "Welcome! Complete your first sessions to see your performance summary. We're excited to support your tutoring journey!",
        what_went_well: "Getting started with new students",
        improvement_suggestion: "Focus on building rapport and setting clear goals in your first few sessions"
      }
    else
      avg = calculate_average(scores)
      {
        trend: :insufficient_data,
        average_sqs: avg.round(1),
        summary: "You're off to a #{avg >= 80 ? 'great' : 'good'} start! Complete a few more sessions to see detailed trends and insights.",
        what_went_well: "Building your session history",
        improvement_suggestion: "Keep up the consistent work as you establish your tutoring patterns"
      }
    end
  end

  def generate_summary_text(trend, avg_score, session_count)
    case trend
    when :improving
      if avg_score >= 85
        "Excellent work! Your recent #{session_count} sessions show strong improvement, " \
        "with an average quality score of #{avg_score.round(1)}. Students are clearly benefiting from your sessions."
      else
        "Great progress! Your session quality has been improving consistently over your last #{session_count} sessions. " \
        "Keep building on this positive momentum!"
      end
    
    when :declining
      if avg_score >= 75
        "Your recent #{session_count} sessions average #{avg_score.round(1)}, which is still solid. " \
        "There's been a slight dip recently, but this is a normal part of tutoring. " \
        "Let's identify opportunities to get back on track."
      else
        "Over your last #{session_count} sessions, there's been some variation in session quality. " \
        "This is completely normal! Let's focus on what's working and build from there."
      end
    
    when :stable
      if avg_score >= 85
        "Excellent consistency! Your sessions are maintaining a high quality score of #{avg_score.round(1)} " \
        "across #{session_count} recent sessions. Students appreciate your reliable approach."
      elsif avg_score >= 75
        "You're maintaining consistent session quality at #{avg_score.round(1)} over #{session_count} sessions. " \
        "There's opportunity to level up even further!"
      else
        "Your recent #{session_count} sessions show consistent patterns. " \
        "Let's explore some strategies to boost your session quality further."
      end
    end
  end

  def generate_what_went_well(avg_score, trend)
    if avg_score >= 90
      "Your sessions are consistently excellent! You're maintaining strong punctuality, full session durations, " \
      "and smooth technical experiences."
    elsif avg_score >= 80
      "You're delivering quality sessions with good punctuality and session completion rates."
    elsif avg_score >= 70
      "You're showing solid fundamentals in your tutoring sessions."
    elsif trend == :improving
      "You're making positive progress and learning from each session."
    else
      "You're building experience and developing your tutoring approach."
    end
  end

  def generate_improvement_suggestion(avg_score, trend)
    if avg_score >= 90
      "Continue your excellent work! Consider mentoring other tutors or sharing what works for you."
    elsif avg_score >= 80
      "Focus on consistency: aim to start sessions within 2 minutes of scheduled time and complete full durations."
    elsif avg_score >= 70
      "Pay attention to session timing: starting on time and completing full sessions makes a big difference."
    elsif trend == :declining
      "Review your recent sessions: are there patterns in timing or technical issues? Small adjustments can help."
    else
      "Focus on the basics: arrive on time, complete full session durations, and minimize technical disruptions."
    end
  end
end

