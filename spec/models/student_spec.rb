require 'rails_helper'

RSpec.describe Student, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      student = Student.new(name: 'Jane Smith', email: 'jane@example.com')
      expect(student).to be_valid
    end

    it 'requires a name' do
      student = Student.new(email: 'jane@example.com')
      expect(student).not_to be_valid
      expect(student.errors[:name]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'has many sessions' do
      expect(Student.reflect_on_association(:sessions)).not_to be_nil
    end
  end
end
