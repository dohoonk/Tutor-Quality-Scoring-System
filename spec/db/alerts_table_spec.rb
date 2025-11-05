require 'rails_helper'

RSpec.describe 'alerts table', type: :model do
  it 'exists in the database' do
    expect(ActiveRecord::Base.connection.table_exists?(:alerts)).to be true
  end

  describe 'columns' do
    let(:columns) { ActiveRecord::Base.connection.columns(:alerts) }
    let(:column_names) { columns.map(&:name) }

    it 'has tutor_id column' do
      expect(column_names).to include('tutor_id')
      tutor_id_column = columns.find { |c| c.name == 'tutor_id' }
      expect(tutor_id_column.null).to be false
    end

    it 'has alert_type column' do
      expect(column_names).to include('alert_type')
    end

    it 'has severity column' do
      expect(column_names).to include('severity')
    end

    it 'has status column' do
      expect(column_names).to include('status')
    end

    it 'has triggered_at column' do
      expect(column_names).to include('triggered_at')
      triggered_at_column = columns.find { |c| c.name == 'triggered_at' }
      expect(triggered_at_column.type).to eq(:datetime)
    end

    it 'has resolved_at column' do
      expect(column_names).to include('resolved_at')
      resolved_at_column = columns.find { |c| c.name == 'resolved_at' }
      expect(resolved_at_column.type).to eq(:datetime)
      expect(resolved_at_column.null).to be true
    end

    it 'has metadata column as jsonb' do
      expect(column_names).to include('metadata')
      metadata_column = columns.find { |c| c.name == 'metadata' }
      expect(metadata_column.sql_type).to include('jsonb')
    end
  end
end

