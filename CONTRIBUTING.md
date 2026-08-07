# Contributing

Cakebox is an early prototype. Small, focused pull requests are easiest to review.

Good first contributions:

- improve docs;
- add smoke tests;
- tighten fragment contracts;
- extract inline CSS/JS into a cleaner asset pipeline;
- add benchmark scripts;
- improve the demo UI without changing the core architecture.

Before opening a PR:

```bash
cabal build
curl -sS http://127.0.0.1:8098/health
```

Please keep runtime files, local traces, build output, and provider secrets out of commits.

