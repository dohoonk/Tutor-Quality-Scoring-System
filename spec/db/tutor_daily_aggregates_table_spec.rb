require 'rails_helper'

RSpec.describe 'tutor_daily_aggregates table', type: :model do
  it 'exists in the database' do
    expect(ActiveRecord::Base.connection.table_exists?(:tutor_daily_aggregates)).to be true
  end

  describe 'columns' do
    let(:columns) { ActiveRecord::Base.connection.columns(:tutor_daily_aggregates) }
    let(:column_names) { columns.map(&:name) }

    it 'has tutor_id column' do
      expect(column_names).to include('tutor_id')
      tutor_id_column = columns.find { |c| c.name == 'tutor_id' }
      expect(tutor_id_column.null).to be false
    end

    it 'has date column' do
      expect(column_names).to include('date')
      date_column = columns.find { |c| c.name == 'date' }
      expect(date_column.type).to eq(:date)
    end

    it 'has sessions_completed column' do
      expect(column_names).to include('sessions_completed')
    end

    it 'has reschedules_tutor_initiated column' do
      expect(column_names).to include('reschedules_tutor_initiated')
    end

    it 'has no_shows column' do
      expect(column_names).to include('no_shows')
    end

    it 'has avg_lateness_min column' do
      expect(column_names).to include('avg_lateness_min')
      lateness_column = columns.find { |c| c.name == 'avg_lateness_min' }
      expect(lateness_column.type).to eq(:decimal)
    end
  end

  describe 'unique constraint' do
    it 'has unique index on (tutor_id, date)' do
      indexes = ActiveRecord::Base.connection.indexes(:tutor_daily_aggregates)
      unique_index = indexes.find { |idx| idx.columns == ['tutor_id', 'date'] && idx.unique }
      expect(unique_index).not_to be_nil
    end
  end
end

