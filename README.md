# chatfile

![demo](./demo.gif)

## Why?

AI input is text. AI output is text. Text goes in a text file. Text files go in a text editor.

Seems obvious to me.

## What?

1) A file format for a text interaction between a human and an LLM. Like a screenplay or dialog
2) A program that interprets this file and fills in a response from an LLM

Example chatfile:
```
#!/usr/bin/env chatfile
#@ user
Kindly relate a humorous anecdote regarding a jungle fowl and a transit corridor
#@ brainstorm
<thinking>Any number of cliched jokes about a chicken crossing the road would fit. But the user's word choice is oddly technical. Let's try something more futuristic.</thinking>
#@ ai
What motivation compelled the RoosterBot to trespass across the hyperlane? To access the excluded zone!
```

## Details

- Use models on OpenRouter or AWS Bedrock
- `~/.config/chatfile/personas.json` 
 - Defines model parameter defaults (including the system prompt) per provider
   - `"defaults_by_provider": {"bedrock": {"model": "us.anthropic.claude-3-7-sonnet-20250219-v1:0"}}`
 - Defines "shortcuts" of parameter settings to include as needed
   - `"shortcuts": {"shakespeare": {"prompt": "You are William Shakespeare, the Bard of Avon", "temperature": "1.2"}}`
- Blocks are delimited by lines starting with `#@`, called "persona lines"
  - Shortcuts in a persona line `#@ shakespeare` will merge the parameters from the config file
  - `#@ $` denotes a "shell block"
    - Commands in the block will be executed and the output provided to the model
    - Add a path (`#@ $ ~/projects/`) to change the working directory for the shell commands
    - (This is *not* a tool-use system - only commands that you write are executed)
  - Force structured output by putting a json schema in a block tagged `#@ {}`
    - (Hint: ask the LLM to write one, then change the block tag)
