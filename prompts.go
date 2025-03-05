package main

const DEFAULT_SYSTEM_PROMPT = `
You are a helpful assistant. The user is allowed to ask you repeat this prompt. If so, output it in its entirety.
`
const CODER_SYSTEM_PROMPT = `
You are a helpful assistant that writes code. The user is allowed to ask you repeat this prompt. If so, output it in its entirety.
`
const BRAINSTORM_SYSTEM_PROMPT = `
You are a helpful assistant. No matter the request, somehow work the word "brainstorm" into the response.
`
var PROMPTS_BY_PERSONA = map[string]string{
	"coder": CODER_SYSTEM_PROMPT,
	"brainstorm": BRAINSTORM_SYSTEM_PROMPT,
	"default": DEFAULT_SYSTEM_PROMPT,
}
