## How to use

Install:

```sh
gem install prreview
```

Run this command with a PR URL:

```sh
prreview -u https://github.com/owner/repo/pull/123
```

Or use more options:

```
prreview --help
prreview --url https://github.com/owner/repo/pull/123 --all-content --prompt "Are there any security issues?"
```

Now, just paste the PR details into ChatGPT, Claude, or any LLM for review.

## What it does

PrReview collects key details about a PR, including:

- PR description, commits, and comments
- Linked issues
- Changed files and their content
- The full PR diff

It then copies everything to your clipboard.

## Why prompt

Advantages over LLM integrations:

- You're free to use the LLM of your choice
- You can continue the conversation with the LLM right in the chat, asking to pay attention to a specific part of the PR
- The gem is simpler

However, in the future we might add some optional integrations.

## Requirements

- Ruby
- `GITHUB_TOKEN` environment variable

## License

MIT License
