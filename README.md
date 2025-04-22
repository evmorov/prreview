## How to use

Run this command with a PR URL:

```sh
bundle exec ruby pr_review.rb --help
bundle exec ruby pr_review.rb -u https://github.com/evmorov/pr-review-prompt/pull/2
```

Now, just paste the PR details into ChatGPT, Claude, or any LLM for review.

## What it does

PrReview collects key details about a PR, including:

- PR description, commits, and comments
- Linked issues
- Changed files and their content
- The full PR diff

It then copies everything to your clipboard.

## Requirements

- Ruby
- GITHUB_TOKEN environment variable

## License

MIT License
