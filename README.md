`chatfile` is
1) a specification for a textfile format ".chat" representing a chat with an LLM
2) a CLI tool for "running" a chatfile, for the LLM to fill in the blocks assigned to it. Usually this means appending a new block.

Example:

```
#!/usr/bin/env chatfile
#% user
Hello, how are you?

#% assistant
I'm fine, thank you!

```

A block is delimited by a line starting with `#%`. Any other text on this line is a reference to a "role". By default, these are "user" and "assistant", but other templates and parameters for the LLM can also be referenced.



