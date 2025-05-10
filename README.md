# chatfile

1) A file format for a text interaction between a human and an LLM
2) A program that interprets this file, sends it to an LLM endpoint, and fills in the response

Example chatfile:
```
#! /usr/bin/env chatfile
#@ user
Kindly relate a humorous anecdote regarding a jungle fowl and a transit corridor
#@ brainstorm
Any number of cliched jokes about a chicken crossing the road would fit. But the user's word choice is oddly technical. Let's try something more futuristic
#@ ai
What motivation compelled the RoosterBot to trespass across the hyperlane? To access the excluded zone!
```

Blocks are delimited by lines starting with `#@`. This line may have keywords that alter model settings or how `chatfile` interprets the conversation.

### Features

- "Just a text file"
  - Edit in `nano` and run from the shell
  - Edit in any IDE and run with a hotkey
- Gives you full control over the conversation
  - System prompts and parameters go in `~/.config/chatfile/personas.json`. Tag a block with the shortcut name `#@ shakespeare` to use them
  - Change history, tweak outputs, mix-and-match models and prompts, repurpose blocks, delete and retry
- Force structured output by putting a json schema in a block tagged `#@ {}`
  - (Hint: ask the LLM to write one, then change the block tag)
- Add context by including a shell block (`#@ $`)
  - Commands in the block will be executed and the output provided to the model
  -
- Uses any model on OpenRouter or AWS Bedrock

