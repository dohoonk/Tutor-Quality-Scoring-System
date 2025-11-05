class CreateSessionTranscripts < ActiveRecord::Migration[8.0]
  def change
    create_table :session_transcripts do |t|
      t.references :session, null: false, foreign_key: true
      t.jsonb :payload

      t.timestamps
    end
  end
end
