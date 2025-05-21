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

## Tips

- Run `prreview` after you've thoroughly reviewed the PR. It works best when you understand the changes well.
- Don't hesitate to try different LLMs or refresh the response to see if something new comes up.
- Use `--all-content` and other extra options — they can significantly improve results for some PRs.
- After the LLM responds, ask "Anything else?" to potentially uncover more issues.

## Requirements

- Ruby
- `GITHUB_TOKEN` environment variable

## License

MIT License
