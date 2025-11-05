require 'rails_helper'

RSpec.describe Tutor, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      tutor = Tutor.new(name: 'John Doe', email: 'john@example.com')
      expect(tutor).to be_valid
    end

    it 'requires a name' do
      tutor = Tutor.new(email: 'john@example.com')
      expect(tutor).not_to be_valid
      expect(tutor.errors[:name]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'has many sessions' do
      expect(Tutor.reflect_on_association(:sessions)).not_to be_nil
    end
  end
end
