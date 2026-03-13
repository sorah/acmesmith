require 'spec_helper'
require 'acmesmith/subject_name_filter'

RSpec.describe Acmesmith::SubjectNameFilter do
  describe '#match?' do
    context 'with no filter' do
      subject { described_class.new }

      it 'matches any domain' do
        expect(subject.match?('example.com')).to eq true
        expect(subject.match?('anything.example.org')).to eq true
      end
    end

    context 'with subject_name_exact' do
      subject { described_class.new(subject_name_exact: ['example.com', 'example.org']) }

      it 'matches exact domain names' do
        expect(subject.match?('example.com')).to eq true
        expect(subject.match?('example.org')).to eq true
      end

      it 'does not match other domains' do
        expect(subject.match?('sub.example.com')).to eq false
        expect(subject.match?('example.net')).to eq false
      end
    end

    context 'with subject_name_suffix' do
      subject { described_class.new(subject_name_suffix: ['.example.com']) }

      it 'matches domains ending with suffix' do
        expect(subject.match?('sub.example.com')).to eq true
        expect(subject.match?('deep.sub.example.com')).to eq true
      end

      it 'does not match non-matching domains' do
        expect(subject.match?('example.com')).to eq false
        expect(subject.match?('example.org')).to eq false
      end
    end

    context 'with subject_name_regexp' do
      subject { described_class.new(subject_name_regexp: ['\Aapp\d+\.example\.com\z']) }

      it 'matches domains matching regexp' do
        expect(subject.match?('app1.example.com')).to eq true
        expect(subject.match?('app99.example.com')).to eq true
      end

      it 'does not match non-matching domains' do
        expect(subject.match?('web1.example.com')).to eq false
      end
    end

    context 'with combined filters' do
      subject do
        described_class.new(
          subject_name_exact: ['exact.example.com'],
          subject_name_suffix: ['.example.com'],
        )
      end

      it 'requires all filters to match' do
        expect(subject.match?('exact.example.com')).to eq true
        expect(subject.match?('other.example.com')).to eq false
      end
    end
  end
end
