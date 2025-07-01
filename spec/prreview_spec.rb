# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Prreview do
  it 'has a version number' do
    expect(Prreview::VERSION).not_to be(nil)
  end
end

RSpec.describe Prreview::CLI do
  context 'when GITHUB_TOKEN is not set' do
    around do |example|
      original_env = ENV.to_hash
      original_argv = ARGV.dup

      ENV.delete('GITHUB_TOKEN')
      ARGV.replace(%w[https://github.com/evmorov/prreview/pull/2])

      example.run

      ENV.replace(original_env)
      ARGV.replace(original_argv)
    end

    it 'aborts with a clear error message' do
      abort_message = nil
      allow_any_instance_of(Prreview::CLI).to(receive(:abort)) { |_, message| abort_message = message }

      Prreview::CLI.new

      expect(abort_message).to eq('Error: GITHUB_TOKEN is not set.')
    end
  end
end
