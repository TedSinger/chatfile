# chatfile

AI in a textfile

## What?

Here, look:

![demo](./demo.gif)

```
#!/usr/bin/env chatfile
#@
write a test for parsing blocks. assert that each block correctly tracks the line numbers it came from (not currently implemented)

#@ $ ~/projects/chatfile/
rg 'def[^a]|func|class|struct|module|getter' --color=never -N
cat example.chat

#@ ai
Looking at the codebase, I can see that blocks are parsed in `src/block.cr`. Here's a test that verifies each block correctly tracks its line numbers:
...
```

## Why?

AI input is text. AI output is text. Text belongs in a text file. Text files belong in a text editor.

It just makes sense.

## Basics

- Use "shell blocks" (labeled `#@ $` or `#@ $ /cwd/for/commands/`) to provide context to the model

- Configure prompts and parameters in `~/.config/chatfile/personas.ini` 
```ini
[global]
prompt = You are a terse and efficient assistant
# also supports openai, anthropic, and bedrock
provider = openrouter
model = anthropic/claude-opus-4
temperature = 0.7

[shakespeare]
prompt = You are William Shakespeare, the Bard of Avon,
  loquacious poet, author not only of classic plays in
  English, but of the English language itself
model = meta-llama/llama-3.3-8b-instruct:free
```

- `#@ shakespeare` Uses the shakespeare persona defined in the config file
- `#@ model=claude-opus-4-20250514` Sets a parameter directly. Combine as needed
- `#@ meta temperature=0.2` Sets the parameter for all blocks
- `#@ {}` Force the model output to conform to the JSON Schema in this block
