require 'rails_helper'

RSpec.describe 'scores table', type: :model do
  it 'exists in the database' do
    expect(ActiveRecord::Base.connection.table_exists?(:scores)).to be true
  end

  describe 'columns' do
    let(:columns) { ActiveRecord::Base.connection.columns(:scores) }
    let(:column_names) { columns.map(&:name) }

    it 'has session_id column' do
      expect(column_names).to include('session_id')
      session_id_column = columns.find { |c| c.name == 'session_id' }
      expect(session_id_column.null).to be true
    end

    it 'has tutor_id column' do
      expect(column_names).to include('tutor_id')
      tutor_id_column = columns.find { |c| c.name == 'tutor_id' }
      expect(tutor_id_column.null).to be false
    end

    it 'has score_type column' do
      expect(column_names).to include('score_type')
    end

    it 'has value column' do
      expect(column_names).to include('value')
      value_column = columns.find { |c| c.name == 'value' }
      expect(value_column.type).to eq(:decimal)
    end

    it 'has components column as jsonb' do
      expect(column_names).to include('components')
      components_column = columns.find { |c| c.name == 'components' }
      expect(components_column.sql_type).to include('jsonb')
    end

    it 'has computed_at column' do
      expect(column_names).to include('computed_at')
      computed_at_column = columns.find { |c| c.name == 'computed_at' }
      expect(computed_at_column.type).to eq(:datetime)
    end
  end

  describe 'indexes' do
    it 'has index on (tutor_id, score_type)' do
      indexes = ActiveRecord::Base.connection.indexes(:scores)
      composite_index = indexes.find { |idx| idx.columns == ['tutor_id', 'score_type'] }
      expect(composite_index).not_to be_nil
    end

    it 'has index on session_id' do
      indexes = ActiveRecord::Base.connection.indexes(:scores)
      session_index = indexes.find { |idx| idx.columns == ['session_id'] }
      expect(session_index).not_to be_nil
    end
  end
end

