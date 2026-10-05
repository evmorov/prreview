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

RSpec.describe Prreview::CLI, '#extract_refs' do
  subject(:cli) { Prreview::CLI.allocate }

  let(:source) { { owner: 'owner', repo: 'repo', name: 'owner/repo#1' } }

  def names(text)
    cli.send(:extract_refs, text, Prreview::CLI::URL_REGEX, source:).map { |ref| ref[:name] }
  end

  it 'ignores references inside HTML comments' do
    text = <<~MD
      Fixes #2
      <!-- Link the issue, e.g. #3 or other/repo#4 -->
      <!--
        https://github.com/other/repo/issues/5
      -->
      See other/repo#6
    MD

    expect(names(text)).to eq(%w[owner/repo#2 other/repo#6])
  end

  it 'ignores references in an unclosed HTML comment' do
    expect(names("Fixes #2\n<!-- #3")).to eq(%w[owner/repo#2])
  end
end
