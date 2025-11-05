require 'rails_helper'

RSpec.describe 'tutor_churn_scores table', type: :model do
  it 'exists in the database' do
    expect(ActiveRecord::Base.connection.table_exists?(:tutor_churn_scores)).to be true
  end

  describe 'columns' do
    let(:columns) { ActiveRecord::Base.connection.columns(:tutor_churn_scores) }
    let(:column_names) { columns.map(&:name) }

    it 'has tutor_id column' do
      expect(column_names).to include('tutor_id')
      tutor_id_column = columns.find { |c| c.name == 'tutor_id' }
      expect(tutor_id_column.null).to be false
    end

    it 'has tcrs_value column' do
      expect(column_names).to include('tcrs_value')
      tcrs_column = columns.find { |c| c.name == 'tcrs_value' }
      expect(tcrs_column.type).to eq(:decimal)
    end

    it 'has computed_at column' do
      expect(column_names).to include('computed_at')
      computed_at_column = columns.find { |c| c.name == 'computed_at' }
      expect(computed_at_column.type).to eq(:datetime)
    end

    it 'has components column as jsonb' do
      expect(column_names).to include('components')
      components_column = columns.find { |c| c.name == 'components' }
      expect(components_column.sql_type).to include('jsonb')
    end
  end

  describe 'indexes' do
    it 'has index on tutor_id' do
      indexes = ActiveRecord::Base.connection.indexes(:tutor_churn_scores)
      tutor_index = indexes.find { |idx| idx.columns == ['tutor_id'] }
      expect(tutor_index).not_to be_nil
    end
  end
end

