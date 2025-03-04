class PrReview
  def initialize
    @pr_url = ARGV[0]
    raise "No Github URL is provided" if @pr_url.nil? || @pr_url.empty?

    @additional_info = ARGV[1]
  end

  def run
    prompt = []

    prompt << @pr_url

    readme = `gh repo view #{repo_url}`
    prompt << wrap_content('README.md', remove_markdown(readme))

    details = `gh pr view #{@pr_url}`
    prompt << wrap_content('PR description', remove_markdown(details))

    diff = `gh pr diff #{@pr_url}`
    prompt << wrap_content('PR diff', diff)

    prompt << files

    task = "Check the PR. Do you see any problems there?"
    prompt << wrap_content('Your task', task)

    IO.popen('pbcopy', 'w') { |io| io.puts(prompt) }
  end

  private

  def repo_url
    @repo_url ||= @pr_url.split('/pull')[0]
  end

  def repo_api_path
    @repo_api_path ||= "repos/#{repo_url.split('github.com/')[1]}/contents"
  end

  def files
    result = []
    file_paths = `gh pr diff --name-only #{@pr_url}`

    file_paths.split("\n").each do |file_path|
      content = `gh api #{repo_api_path}/#{file_path} | jq -r '.content' | base64 --decode`
      result << wrap_content(file_path, content)
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

  def remove_markdown(content)
    content.delete("`").delete("#")
  end
end

PrReview.new.run
