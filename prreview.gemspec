# frozen_string_literal: true

require_relative 'lib/prreview/version'

Gem::Specification.new do |spec|
  spec.name = 'prreview'
  spec.version = Prreview::VERSION
  spec.authors = ['Evgenii Morozov']
  spec.email = ['evmorov@gmail.com']

  spec.summary = 'A CLI tool that formats GitHub PRs for LLM code reviews.'
  spec.description = 'PrReview collects PR data from GitHub (description, commits, comments, linked issues, and code changes) and formats it as XML. Paste this XML into any LLM like ChatGPT or Claude to get helpful code reviews.'
  spec.homepage = 'https://github.com/evmorov/prreview'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'clipboard', '~> 2.0'
  spec.add_dependency 'faraday-retry', '~> 2.3'
  spec.add_dependency 'nokogiri', '~> 1.18'
  spec.add_dependency 'octokit', '~> 10.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
