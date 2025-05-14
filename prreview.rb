# frozen_string_literal: true

require 'base64'
require 'clipboard'
require 'nokogiri'
require 'octokit'
require 'optparse'

class Prreview
  DEFAULT_PROMPT = 'Your task is to review this pull request. Do you see any problems there?'
  DEFAULT_ISSUES_LIMIT = 10

  # url or owner/repo#123 or #123
  URL_REGEX = %r{
    https?://github\.com/
      (?<owner>[\w.-]+) /
      (?<repo>[\w.-]+) /
      (?:pull|issues) /
      (?<number>\d+)
    |
    (?:
      (?<owner>[\w.-]+) /
      (?<repo>[\w.-]+)
    )?
    \#
    (?<number>\d+)
  }x

  def initialize
    parse_options!
    parse_url!
    initialize_client
  end

  def process
    fetch_pull_request
    fetch_issues
    build_xml
    copy_result_to_clipboard
  end

  private

  def parse_options!
    @prompt = DEFAULT_PROMPT
    @include_content = false
    @issues_limit = DEFAULT_ISSUES_LIMIT

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} -u URL [options]"

      opts.on('-u', '--url URL', 'Pull‑request URL (https://github.com/owner/repo/pull/1)') { |v| @url = v }
      opts.on('-p', '--prompt PROMPT', 'Custom LLM prompt') { |v| @prompt = v }
      opts.on('-a', '--all-content', 'Include full file contents') { @include_content = true }
      opts.on('-l', '--limit LIMIT', Integer, "Limit number of issues fetched (default: #{DEFAULT_ISSUES_LIMIT})") { |v| @issues_limit = v }
      opts.on('-h', '--help', 'Show help') do
        puts opts
        exit
      end
    end

    parser.parse!
  end

  def parse_url!
    abort 'Error: Pull-request URL missing. Use -u or --url.' if @url.to_s.empty?

    match = @url.match(URL_REGEX)
    abort 'Error: Invalid URL format. See --help for usage.' unless match

    @owner = match[:owner]
    @repo = match[:repo]
    @pr_number = match[:number].to_i
    @full_repo = "#{@owner}/#{@repo}"
  end

  def initialize_client
    access_token = ENV.fetch('GITHUB_TOKEN', nil)
    abort 'Error: GITHUB_TOKEN is not set' if access_token.to_s.empty?

    @client = Octokit::Client.new(access_token:, auto_paginate: true)
  rescue Octokit::Unauthorized
    abort 'Error: Invalid GITHUB_TOKEN'
  end

  def fetch_pull_request
    puts "Fetching PR ##{@pr_number} for #{@full_repo}"

    @pull_request = @client.pull_request(@full_repo, @pr_number)
    @comments = @client.issue_comments(@full_repo, @pr_number).map(&:body)
    @commits = @client.pull_request_commits(@full_repo, @pr_number).map { |c| c.commit.message }
    @files = @client.pull_request_files(@full_repo, @pr_number).map do |file|
      {
        filename: file.filename,
        patch: file.patch || '(no patch data)',
        content: @include_content ? fetch_file_content(file.filename) : '(no content)'
      }
    end
  end

  def fetch_file_content(path)
    puts "Fetching file content for #{path}"

    content = @client.contents(@full_repo, path:, ref: @pull_request.head.sha)
    Base64.decode64(content[:content])
  rescue Octokit::NotFound
    '(file content not found)'
  end

  def fetch_issues
    @issues = []

    text = [@pull_request.body, *@comments].join("\n")
    queue = extract_refs(text, URL_REGEX)
    seen = Set.new

    until queue.empty? || @issues.length >= @issues_limit
      ref = queue.shift
      key = ref[:key]
      next if seen.include?(key)

      seen << key

      issue = fetch_issue(ref)
      next unless issue

      @issues << issue

      new_text = [issue[:description], *issue[:comments]].join("\n")
      new_refs = extract_refs(new_text, URL_REGEX).reject { |nref| seen.include?(nref[:key]) }
      queue.concat(new_refs)
    end

    puts "Fetched #{@issues.length} issues (limit: #{@issues_limit})"
  end

  def extract_refs(text, pattern)
    text.to_enum(:scan, pattern).filter_map do
      m = Regexp.last_match
      next unless m[:number]

      {
        owner: m[:owner] || @owner,
        repo: m[:repo] || @repo,
        number: m[:number].to_i,
        key: "#{m[:owner]}/#{m[:repo]}##{m[:number]}"
      }
    end
  end

  def fetch_issue(ref)
    full_repo = "#{ref[:owner]}/#{ref[:repo]}"
    number = ref[:number]

    puts "Fetching issue ##{number} for #{full_repo}"

    issue = @client.issue(full_repo, number)
    {
      full_repo:,
      number:,
      title: issue.title,
      description: issue.body,
      comments: @client.issue_comments(full_repo, number).map(&:body)
    }
  rescue Octokit::NotFound
    puts "Issue #{number} for #{full_repo} not found, skipping"
    nil
  end

  def build_xml
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |x|
      x.prompt do
        x.task @prompt

        x.pull_request do
          x.number @pr_number
          x.title @pull_request.title
          x.description @pull_request.body

          @comments.each { |c| x.comment_ c }
          @commits.each { |m| x.commit m }

          @files.each do |file|
            x.file do
              x.filename file[:filename]
              x.content file[:content]
              x.patch file[:patch]
            end
          end
        end

        @issues.each do |issue|
          x.issue do
            x.repo issue[:full_repo]
            x.number issue[:number]
            x.title issue[:title]
            x.description issue[:description]

            issue[:comments].each { |c| x.comment_ c }
          end
        end

        x.task @prompt
      end
    end

    @xml = builder.doc.root.to_xml
  end

  def copy_result_to_clipboard
    Clipboard.copy(@xml)
    puts 'XML prompt generated and copied to clipboard.'
  end
end

Prreview.new.process
