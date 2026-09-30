[![Gem Version](https://badge.fury.io/rb/prreview.svg)](https://badge.fury.io/rb/prreview)

## How to use

Install:

```sh
gem install prreview
```

Run this command with a PR URL:

```sh
prreview https://github.com/owner/repo/pull/123
```

Or use more options:

```
prreview --help
prreview https://github.com/owner/repo/pull/123 --diff --comments --linked-issues --prompt "Are there any security issues?"
prreview https://github.com/owner/repo/pull/123 --prompt ~/my-review-prompt.txt
```

`--prompt` accepts either the prompt text or a path to a file containing it.

Now, just paste the PR details into ChatGPT, Claude, or any LLM for review.

## What it does

By default, PrReview collects only the PR title and description. Add more with flags:

- `--diff` — the PR diff
- `--all-content` — full content of changed files
- `--commits` — commits
- `--comments` — PR comments and code comments
- `--linked-issues [LIMIT]` — linked issues (default limit: 5)
- `--optional PATHS` — local files

It then copies everything to your clipboard.

## Why prompt

Advantages over LLM integrations:

- You're free to use the LLM of your choice
- You can continue the conversation with the LLM right in the chat, asking to pay attention to a specific part of the PR
- The gem is simpler

However, in the future we might add some optional integrations.

## Tips

- A well-written PR and linked issue description make a big difference — and are good practice anyway.
- Run `prreview` after you've thoroughly reviewed the PR. It works best when you understand the changes well.
- Don't hesitate to try different LLMs or refresh the response to see if something new comes up.
- Use `--diff`, `--all-content`, and other extra options — they can significantly improve results for some PRs.
- After the LLM responds, to potentially uncover more issues:
  - Ask "Anything else?".
  - If the response has a list of problems, try responding to each of them, giving the LLM more context.

## Requirements

- Ruby
- `GITHUB_TOKEN` environment
  variable. [GitHub Docs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

## License

MIT License
