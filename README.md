## How to use

Run this command with a PR URL:

```sh
ruby pr_review.rb https://github.com/evmorov/pr-review-prompt/pull/2
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
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and logged in:

```sh
brew install gh
gh auth login
```

## Notes

- Works on macOS (`pbcopy`). Modify for other systems if needed.
- Requires access to the repo via `gh`.

## License

MIT License
