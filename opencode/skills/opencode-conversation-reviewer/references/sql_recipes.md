# opencode db: SQL recipes

Use these when you need custom slices beyond `scripts/opencode_conversation_digest.py`.

All commands support `--format tsv` (compact) and `--format json` (parseable).

## List tables

```bash
opencode db "select name from sqlite_master where type='table' order by name;" --format tsv
```

## Recent sessions for a directory

Exact match:

```bash
opencode db "select id, directory, title, time_created, time_updated from session where directory = '/abs/path' order by time_created desc limit 20;" --format tsv
```

Include sessions created in subdirectories:

```bash
opencode db "select id, directory, title, time_created, time_updated from session where directory = '/abs/path' or directory like '/abs/path/%' order by time_created desc limit 20;" --format tsv
```

## Session diff summary

```bash
opencode db "select id, title, summary_files, summary_additions, summary_deletions from session where id = 'ses_...'" --format tsv
```

## Open todos (dangling work)

```bash
opencode db "select content, status, priority, position, time_updated from todo where session_id = 'ses_...' and status not in ('completed','cancelled') order by position;" --format tsv
```

## Detect last-message errors / incomplete runs

Last message JSON (look for `error` or missing `time.completed`):

```bash
opencode db "select data from message where session_id = 'ses_...' order by time_created desc limit 1;" --format json
```

## Extract the first user prompt (text part)

```bash
opencode db "select part.data as part_data from part join message on message.id = part.message_id where part.session_id = 'ses_...' and message.data like '%\"role\":\"user\"%' and part.data like '%\"type\":\"text\"%' order by part.time_created asc limit 1;" --format json
```

## Extract the last assistant output (text part)

```bash
opencode db "select part.data as part_data from part join message on message.id = part.message_id where part.session_id = 'ses_...' and message.data like '%\"role\":\"assistant\"%' and part.data like '%\"type\":\"text\"%' order by part.time_created desc limit 1;" --format json
```
