# Security policy

- Runtime secrets never belong in this repository. `config.example.yaml` files
  carry `${HERMES_NTFY_TOPIC}` style placeholders; real topics, tokens and API
  keys live in your Hermes runtime (`~/.hermes/.env`, per-profile configs) and
  are not published here.
- `memories/`, `auth.json`, `state.db*`, sessions, logs and caches are
  deliberately excluded from the repo and from `install.sh` writes.
- The stack sends material conclusions to a human gate over ntfy; treat any
  notification topic you configure as public unless you protect it.
- Do not open issues for confidential reports; use GitHub private vulnerability
  reporting.
