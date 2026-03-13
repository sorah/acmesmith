require 'spec_helper'
require 'acmesmith/config'

RSpec.describe Acmesmith::Config do
  let(:base_config) do
    {
      'directory' => 'https://acme-staging-v02.api.letsencrypt.org/directory',
      'storage' => { 'type' => 'filesystem', 'path' => './tmp' },
      'challenge_responders' => [{ 'dns_manual' => {} }],
    }
  end

  describe '#profile_rules' do
    context 'when profiles is absent' do
      it 'returns empty array' do
        config = described_class.new(base_config)
        expect(config.profile_rules).to eq([])
      end
    end

    context 'when profiles is empty array' do
      it 'returns empty array' do
        config = described_class.new(base_config.merge('profiles' => []))
        expect(config.profile_rules).to eq([])
      end
    end

    context 'with a single profile rule with filter' do
      it 'parses correctly' do
        config = described_class.new(base_config.merge('profiles' => [
          { 'name' => 'shortlived', 'filter' => { 'subject_name_suffix' => ['.short.example.com'] } },
        ]))
        rules = config.profile_rules
        expect(rules.size).to eq(1)
        expect(rules[0].name).to eq('shortlived')
        expect(rules[0].filter.match?('test.short.example.com')).to eq(true)
        expect(rules[0].filter.match?('test.example.com')).to eq(false)
      end
    end

    context 'with multiple profile rules' do
      it 'preserves order' do
        config = described_class.new(base_config.merge('profiles' => [
          { 'name' => 'shortlived', 'filter' => { 'subject_name_suffix' => ['.short.example.com'] } },
          { 'name' => 'classic' },
        ]))
        rules = config.profile_rules
        expect(rules.size).to eq(2)
        expect(rules[0].name).to eq('shortlived')
        expect(rules[1].name).to eq('classic')
      end
    end

    context 'with profile rule without filter (matches all)' do
      it 'matches any domain' do
        config = described_class.new(base_config.merge('profiles' => [
          { 'name' => 'classic' },
        ]))
        rules = config.profile_rules
        expect(rules[0].filter.match?('anything.example.com')).to eq(true)
      end
    end
  end

  describe '#validate' do
    context 'when profiles is not an Array' do
      it 'raises ArgumentError' do
        expect {
          described_class.new(base_config.merge('profiles' => 'invalid'))
        }.to raise_error(ArgumentError, "config['profiles'] must be an Array")
      end
    end
  end
end
