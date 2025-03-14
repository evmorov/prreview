# frozen_string_literal: true

require 'open3'
require 'json'

class PrReview
  # https://github.com/evmorov/pr-review-llm/pull/123
  def initialize
    raise 'brew install gh && gh auth login' unless system('gh auth status > /dev/null')

    @pr_url = ARGV.shift
    raise 'No Github URL is provided' if @pr_url.nil? || @pr_url.empty?

    @context_paths = ARGV # optional
    @context_paths.each { |path| raise "No file was found #{path}" unless File.exist?(path) }
  end

  def run
    prompt = []
    prompt << @pr_url

    readme = request_gh("gh repo view #{repo_url}")
    prompt << wrap_content('README.md', limit_lines(readme, 50))

    prompt << details_with_comments
    prompt << linked_issues
    prompt << updated_files
    prompt << context_files

    diff = request_gh("gh pr diff #{@pr_url}")
    prompt << wrap_content('PR diff', diff)

    task = 'Check the PR. Do you see any problems there?'
    prompt << wrap_content('Your task', task)

    IO.popen('pbcopy', 'w') { |io| io.puts(prompt) }
  end

  private

  # https://github.com/evmorov/pr-review-llm
  def repo_url
    @repo_url ||= @pr_url.split('/pull')[0]
  end

  def branch
    @branch ||= request_gh("gh pr view #{@pr_url} --json headRefName -q .headRefName").strip
  end

  # evmorov
  def owner
    @owner ||= repo_url.split('github.com/')[1].split('/')[0]
  end

  # might be evmorov, but might be someone else if it's a fork
  def pr_owner
    @pr_owner ||= request_gh(
      "gh pr view --json headRepositoryOwner #{@pr_url} | jq -r '.headRepositoryOwner.login'"
    ).strip
  end

  # pr-review-llm
  def repo
    @repo ||= repo_url.split('github.com/')[1].split('/')[1]
  end

  # 123
  def pr_number
    @pr_number ||= @pr_url.split('pull/')[1].split('/')[0]
  end

  def details_with_comments
    request = <<~REQ
      gh pr view --json author,body,commits,comments #{@pr_url} |
      jq '{
        author: .author.login,
        body: .body,
        comments: [.comments[] | {author: .author.login, body: .body}],
        commits: [.commits[] | {author: [.authors[0].login], messageHeadline: .messageHeadline, messageBody: .messageBody}]
      }'
    REQ
    details_with_comments = request_gh(request)
    wrap_content('PR description, commits and comments', pretty_json(details_with_comments))
  end

  # Currently only works for issues within the same repository
  # https://github.com/cli/cli/issues/8900
  def linked_issues
    request = <<~REQ
      gh api graphql -F owner='#{owner}' -F repo='#{repo}' -F pr='#{pr_number}' -f query='
      query ($owner: String!, $repo: String!, $pr: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            closingIssuesReferences(first: 100) {
              nodes {
                number
              }
            }
          }
        }
      }' --jq '.data.repository.pullRequest.closingIssuesReferences.nodes[].number'
    REQ
    issue_numbers = request_gh(request)
    issue_numbers.split("\n").map do |issue_number|
      linked_issue(issue_number)
    end
  end

  def linked_issue(issue_number)
    issue_desc = request_gh(%(
      gh api repos/#{owner}/#{repo}/issues/#{issue_number} \
      --jq '"Title: \\(.title)\n--\nBody:\n\n\\(.body)"'
    ).strip)
    issue_comments = request_gh(%(
      gh api --paginate repos/#{owner}/#{repo}/issues/#{issue_number}/comments \
      --jq '.[] | "\\(.user.login): \\(.body)"'
    ).strip)
    wrap_content("Linked issue ##{issue_number}", "#{issue_desc}\n--\nComments:\n\n#{issue_comments}")
  end

  def updated_files
    result = []
    file_paths = request_gh("gh pr diff --name-only #{@pr_url}")
    api_contents_path = "repos/#{pr_owner}/#{repo}/contents"

    file_paths.split("\n").each do |file_path|
      next if %w[readme.md changelog.md].include?(file_path.downcase)

      content = request_gh(%(
        gh api #{api_contents_path}/#{file_path}?ref=#{branch} | jq -r '.content' | base64 --decode
      ).strip)
      next unless content

      result << wrap_content("Updated file: #{file_path}", content)
    end

    result
  end

  def context_files
    @context_paths.map do |path|
      wrap_content("Context file: #{path}", File.read(path))
    end
  end

  def wrap_content(title, content)
    r = []
    r << "\n"
    r << "=========== #{title} ==========="
    r << "\n"
    r << content
  end

  def request_gh(cmd)
    puts cmd.delete("\n")
    stdout, stderr, = Open3.capture3(cmd)

    unless stderr.empty?
      puts stderr
      return
    end

    stdout
  end

  def limit_lines(content, n_lines)
    lines = content.split("\n").take(n_lines)
    lines << '...'
    lines.join("\n")
  end

  def pretty_json(json)
    JSON.pretty_generate(JSON.parse(json))
  end
end

PrReview.new.run
