require 'open3'

class PrReview
  # https://github.com/evmorov/pr-review-llm/pull/123
  def initialize
    @pr_url = ARGV[0]
    raise "No Github URL is provided" if @pr_url.nil? || @pr_url.empty?
  end

  def run
    prompt = []

    prompt << @pr_url

    readme = request_gh("gh repo view #{repo_url}")
    prompt << wrap_content('README.md', remove_markdown(readme))

    details_with_comments = request_gh("gh pr view --json author,body,commits,comments #{@pr_url}")
    prompt << wrap_content('PR description, commits and comments', remove_markdown(details_with_comments))

    prompt << linked_issues

    prompt << updated_files

    diff = request_gh("gh pr diff #{@pr_url}")
    prompt << wrap_content('PR diff', diff)

    task = "Check the PR. Do you see any problems there?"
    prompt << wrap_content('Your task', task)

    IO.popen('pbcopy', 'w') { |io| io.puts(prompt) }
  end

  private

  # repos/evmorov/pr-review-llm/contents/
  def api_contents_path
    @api_contents_path ||= "repos/#{repo_url.split('github.com/')[1]}/contents"
  end

  # https://github.com/evmorov/pr-review-llm
  def repo_url
    @repo_url ||= @pr_url.split('/pull')[0]
  end

  def branch
    @branch ||= request_gh("gh pr view #{@pr_url} --json headRefName -q .headRefName").strip
  end

  # evmorov
  def owner
    @owner ||= repo_url.split('github.com/')[1].split("/")[0]
  end

  # pr-review-llm
  def repo
    @repo ||= repo_url.split('github.com/')[1].split("/")[1]
  end

  # 123
  def pr_number
    @pr_number ||= @pr_url.split('/').last
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
      }'  --jq '.data.repository.pullRequest.closingIssuesReferences.nodes[].number'
    REQ
    issue_numbers = request_gh(request)
    issue_numbers.split("\n").map do |issue_number|
      issue_desc = remove_markdown(
        request_gh(%{gh api repos/#{owner}/#{repo}/issues/#{issue_number} --jq '"Title: \\(.title)\n--\nBody:\n\n\\(.body)"'})
      )
      issue_comments = remove_markdown(
        request_gh(%{gh api --paginate repos/#{owner}/#{repo}/issues/#{issue_number}/comments --jq '.[] | "\\(.user.login): \\(.body)"'})
      )
      wrap_content("Linked issue ##{issue_number}", "#{issue_desc}\n--\nComments:\n\n#{issue_comments}")
    end
  end

  def updated_files
    result = []
    file_paths = request_gh("gh pr diff --name-only #{@pr_url}")

    file_paths.split("\n").each do |file_path|
      content = request_gh("gh api #{api_contents_path}/#{file_path}?ref=#{branch} | jq -r '.content' | base64 --decode")
      next unless content

      result << wrap_content("Updated file: #{file_path}", content)
    end

    result
  end

  def wrap_content(file_name, content)
    r = []
    r << "\n"
    r << "## #{file_name}"
    r << "\n"
    r << "```"
    r << content
    r << "```"
  end

  def request_gh(cmd)
    puts cmd.delete("\n")
    stdout, stderr, status = Open3.capture3(cmd)

    unless stderr.empty?
      puts stderr
      return
    end

    stdout
  end

  def remove_markdown(content)
    content.delete("`").delete("#")
  end
end

PrReview.new.run
