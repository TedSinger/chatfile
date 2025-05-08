# chatfile

1) A file format for a text interaction between a human and an LLM
2) A program that interprets this file, converts it to a shape suitable for a chosen LLM endpoint, sends it, and populates the response

Example chatfile:
```
#! /usr/bin/env chatfile
#@ user
Kindly relate a humorous anecdote regarding a jungle fowl and a transit corridor
#@ brainstorm
Any number of cliched jokes about a chicken crossing the road would fit. But the user's word choice is oddly technical. Let's try something more futuristic
#@ assistant
What motivation compelled the RoosterBot to trespass across the hyperlane? To access the excluded zone!
```

Blocks are delimited by a Persona Line, which begins `#@` and optionally includes API parameter settings or references to "personas". A persona is a prompt and possibly some parameter settings.
