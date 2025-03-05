require 'open3'

class PrReview
  def initialize
    @pr_url = ARGV[0]
    raise "No Github URL is provided" if @pr_url.nil? || @pr_url.empty?
  end

  def run
    prompt = []

    prompt << @pr_url

    readme = request_gh("gh repo view #{repo_url}")
    prompt << wrap_content('README.md', remove_markdown(readme))

    details_with_comments = request_gh("gh pr view --comments #{@pr_url}")
    prompt << wrap_content('PR description and comments', remove_markdown(details_with_comments))

    prompt << files

    diff = request_gh("gh pr diff #{@pr_url}")
    prompt << wrap_content('PR diff', diff)

    task = "Check the PR. Do you see any problems there?"
    prompt << wrap_content('Your task', task)

    IO.popen('pbcopy', 'w') { |io| io.puts(prompt) }
  end

  private

  def files
    result = []
    file_paths = request_gh("gh pr diff --name-only #{@pr_url}")

    file_paths.split("\n").each do |file_path|
      content = request_gh("gh api #{api_contents_path}/#{file_path}?ref=#{branch} | jq -r '.content' | base64 --decode")
      next unless content

      result << wrap_content(file_path, content)
    end

    result
  end

  def api_contents_path
    @api_contents_path ||= "repos/#{repo_url.split('github.com/')[1]}/contents"
  end

  def repo_url
    @repo_url ||= @pr_url.split('/pull')[0]
  end

  def branch
    @branch ||= request_gh("gh pr view #{@pr_url} --json headRefName -q .headRefName").strip
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
    puts cmd
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
