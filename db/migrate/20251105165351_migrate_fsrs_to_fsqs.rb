class MigrateFsrsToFsqs < ActiveRecord::Migration[8.0]
  def up
    # Update score_type from 'fsrs' to 'fsqs' and convert score values
    # Old FSRS: 0-120 scale where 0 = perfect (no risk), 120 = worst (all risk factors)
    # New FSQS: 0-100 scale where 100 = perfect quality, 0 = worst quality
    # Conversion formula: new_score = 100 * (1 - old_score/120)
    
    Score.where(score_type: 'fsrs').find_each do |score|
      old_value = score.value.to_f
      # Convert from 0-120 risk scale (lower is better) to 0-100 quality scale (higher is better)
      new_value = [100 * (1 - old_value / 120.0), 0].max.round(2)
      
      score.update_columns(
        score_type: 'fsqs',
        value: new_value,
        updated_at: Time.current
      )
    end
  end

  def down
    # Reverse: Convert FSQS back to FSRS
    # New FSQS: 0-100 (higher is better) -> Old FSRS: 0-120 (lower is better)
    # Reverse formula: old_score = 120 * (1 - new_score/100)
    
    Score.where(score_type: 'fsqs').find_each do |score|
      new_value = score.value.to_f
      # Convert from 0-100 quality scale back to 0-120 risk scale
      old_value = [120 * (1 - new_value / 100.0), 0].max.round(2)
      
      score.update_columns(
        score_type: 'fsrs',
        value: old_value,
        updated_at: Time.current
      )
    end
  end
end
