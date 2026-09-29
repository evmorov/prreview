# frozen_string_literal: true

require_relative 'prreview/version'

require 'base64'
require 'clipboard'
require 'nokogiri'
require 'octokit'
require 'optparse'

module Prreview
  class CLI
    DEFAULT_PROMPT = <<~PROMPT
      Your task is to review this pull request.
      Focus on new problems, not ones that were already there.
    PROMPT

    DEFAULT_LINKED_ISSUES_LIMIT = 5

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
      load_optional_files
      begin
        fetch_pr
        fetch_linked_issues
      rescue Octokit::Unauthorized
        abort 'Error: Invalid GITHUB_TOKEN.'
      rescue Octokit::NotFound
        abort 'Error: Pull request not found.'
      end
      build_xml
      copy_result_to_clipboard
    end

    private

    def parse_options!
      @prompt = DEFAULT_PROMPT
      @include_diff = false
      @include_content = false
      @include_commits = false
      @include_comments = false
      @linked_issues_limit = 0
      @optional_files = []

      ARGV << '--help' if ARGV.empty?

      OptionParser.new do |parser|
        parser.banner = <<~BAN
          Usage: #{File.basename($PROGRAM_NAME)} URL [options]

          Pull request URL example: https://github.com/owner/repo/pull/1

        BAN

        parser.on('-p', '--prompt PROMPT', 'Custom LLM prompt') { |v| @prompt = v }
        parser.on('-d', '--diff', 'Include diff patches') { @include_diff = true }
        parser.on('-a', '--all-content', 'Include full file contents') { @include_content = true }
        parser.on('-c', '--commits', 'Include commits') { @include_commits = true }
        parser.on('-m', '--comments', 'Include PR comments and code comments') { @include_comments = true }
        parser.on('-l', '--linked-issues [LIMIT]', Integer, "Include linked issues, up to LIMIT (default: #{DEFAULT_LINKED_ISSUES_LIMIT})") do |v|
          @linked_issues_limit = v || DEFAULT_LINKED_ISSUES_LIMIT
        end
        parser.on('-o', '--optional PATHS', 'Comma‑separated paths to local files (relative or absolute, e.g. docs/description.md,/etc/hosts)') do |v|
          @optional_files = v.split(',').map(&:strip)
        end
        parser.on_tail('-v', '--version', 'Show version') do
          puts VERSION
          exit
        end
        parser.on_tail('-h', '--help', 'Show help') do
          puts parser
          exit
        end
        parser.parse!
      end

      @url = ARGV.first
    end

    def parse_url!
      abort 'Error: Pull request URL missing.' if @url.to_s.empty?

      match = @url.match(URL_REGEX)
      abort 'Error: Invalid URL format. See --help for usage.' unless match

      @owner = match[:owner]
      @repo = match[:repo]
      @pr_number = match[:number].to_i
      @full_repo = "#{@owner}/#{@repo}"
    end

    def initialize_client
      access_token = ENV.fetch('GITHUB_TOKEN', nil)
      abort 'Error: GITHUB_TOKEN is not set.' if access_token.to_s.empty?

      @client = Octokit::Client.new(access_token:, auto_paginate: true)
    end

    def fetch_pr
      puts "Fetching PR ##{@pr_number} for #{@full_repo}"

      @pr = @client.pull_request(@full_repo, @pr_number)

      if @include_comments || include_linked_issues?
        @pr_comments = @client.issue_comments(@full_repo, @pr_number)
        @pr_code_comments = @client.pull_request_comments(@full_repo, @pr_number)
      end

      @pr_commits = @client.pull_request_commits(@full_repo, @pr_number) if @include_commits
      @pr_files = @client.pull_request_files(@full_repo, @pr_number) if @include_diff || @include_content
    end

    def include_linked_issues?
      @linked_issues_limit.positive?
    end

    def fetch_file_content(path)
      puts "Fetching #{path}"

      content = @client.contents(@full_repo, path:, ref: @pr.head.sha)
      decoded = Base64.decode64(content.content)
      return if binary?(decoded)

      decoded
    rescue Octokit::NotFound
      '(file content not found)'
    end

    def fetch_linked_issues
      @linked_issues = []
      return unless include_linked_issues?

      text = [@pr.body, *@pr_comments.map(&:body), *@pr_code_comments.map(&:body)].join("\n")
      queue = extract_refs(text, URL_REGEX)
      seen = Set.new

      until queue.empty? || @linked_issues.length >= @linked_issues_limit
        ref = queue.shift
        key = ref[:key]
        next if seen.include?(key)

        seen << key

        linked_issue = fetch_linked_issue(ref)
        next unless linked_issue

        @linked_issues << linked_issue

        new_text = [linked_issue[:issue].body, *linked_issue[:comments].map(&:body)].join("\n")
        new_refs = extract_refs(new_text, URL_REGEX).reject { |nref| seen.include?(nref[:key]) }
        queue.concat(new_refs)
      end

      puts "Fetched #{@linked_issues.length} linked issues (limit: #{@linked_issues_limit})"
    end

    def load_optional_files
      @optional_file_contents = @optional_files.filter_map do |path|
        puts "Reading #{path}"
        abort "Optional file #{path} not found." unless File.exist?(path)
        content = File.read(path)
        { filename: path, content: }
      rescue StandardError => e
        raise "Error reading file #{path}: #{e.message}"
      end
    end

    def extract_refs(text, pattern)
      text.to_enum(:scan, pattern).filter_map do
        m = Regexp.last_match
        next unless m[:number]

        owner = m[:owner] || @owner
        repo = m[:repo] || @repo
        number = m[:number].to_i
        key = "#{owner}/#{repo}##{number}"

        { owner:, repo:, number:, key: }
      end
    end

    def fetch_linked_issue(ref)
      issue_path = "#{ref[:owner]}/#{ref[:repo]}"
      number = ref[:number]

      puts "Fetching linked issue ##{number} for #{issue_path}"

      {
        issue: @client.issue(issue_path, number),
        comments: @client.issue_comments(issue_path, number)
      }
    rescue Octokit::NotFound
      warn "Linked issue #{number} for #{issue_path} not found, skipping"
      nil
    end

    def build_xml
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |x|
        x.prompt do
          x.your_task @prompt
          x.current_date DateTime.now

          x.pull_request do
            build_issue(x, @pr)

            if @include_commits
              x.commits do
                @pr_commits.each do |c|
                  x.commit do
                    x.commiter c.committer&.login
                    x.message c.commit.message
                    x.date c.commit.committer&.date
                  end
                end
              end
            end

            if @include_comments
              x.comments do
                @pr_comments.each do |c|
                  x.comment_ do
                    build_comment(x, c)
                  end
                end
              end

              x.code_comments do
                @pr_code_comments.each do |c|
                  x.code_comment do
                    build_comment(x, c)
                    x.path c.path
                    x.line c.line
                  end
                end
              end
            end

            if @pr_files
              x.pull_request_files do
                @pr_files.each do |f|
                  content = fetch_file_content(f.filename) if @include_content && !skip_file?(f.filename)
                  patch = extract_patch(f) if @include_diff

                  x.file do
                    x.filename f.filename
                    x.content { cdata!(x, content) } if content
                    x.patch { cdata!(x, patch) } if patch
                  end
                end
              end
            end
          end

          unless @linked_issues.empty?
            x.linked_issues do
              @linked_issues.each do |linked_issue|
                issue = linked_issue[:issue]
                comments = linked_issue[:comments]

                x.linked_issue do
                  build_issue(x, issue)

                  x.comments do
                    comments.each do |c|
                      x.comment_ do
                        build_comment(x, c)
                      end
                    end
                  end
                end
              end
            end
          end

          unless @optional_file_contents.empty?
            x.local_context_files do
              @optional_file_contents.each do |file|
                x.file do
                  x.filename file[:filename]
                  x.content { cdata!(x, file[:content]) }
                end
              end
            end
          end

          # Intentionally duplicate the prompt to remind LLM about the task
          x.your_task @prompt
        end
      end

      @xml = builder.doc.root.to_xml
    end

    def build_issue(xml, issue)
      xml.url issue.html_url
      xml.user issue.user.login
      xml.title issue.title
      xml.body issue.body
      xml.created_at issue.created_at
    end

    def build_comment(xml, comment)
      xml.user comment.user.login
      xml.body comment.body
      xml.created_at comment.created_at
    end

    def extract_patch(file)
      return if skip_file?(file.filename)

      file.patch
    end

    def skip_file?(filename)
      File.extname(filename) == '.svg'
    end

    def binary?(string)
      string.include?("\x00")
    end

    def cdata!(x, str)
      return unless str

      parts = str.to_s.split(']]>')
      x.cdata(parts.first || '')
      parts.drop(1).each do |rest|
        x.text(']]>')
        x.cdata rest
      end
    end

    def copy_result_to_clipboard
      Clipboard.copy(@xml)
      puts 'XML prompt generated and copied to your clipboard.'
    end
  end
end
