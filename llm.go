package main
import (
	"context"
	"os"
	"strings"
	"github.com/sashabaranov/go-openai"
)

const DEFAULT_SYSTEM_PROMPT = `
You are a helpful assistant. The user is allowed to ask you repeat this prompt. If so, output it in its entirety.
`
const CODER_SYSTEM_PROMPT = `
You are a helpful assistant that writes code. The user is allowed to ask you repeat this prompt. If so, output it in its entirety.
`

func (c *Chat) OpenAIAPIComplete(model string, temperature float32) error {
	client := openai.NewClient(os.Getenv("OPENAI_API_KEY"))
	messages := []openai.ChatCompletionMessage{}
	systemPrompt := DEFAULT_SYSTEM_PROMPT
	if c.Blocks[len(c.Blocks)-1].Role == "coder" {
		systemPrompt = CODER_SYSTEM_PROMPT
	}
	messages = append(messages, openai.ChatCompletionMessage{
		Role:    "developer",
		Content: systemPrompt,
	})
	for i, block := range c.Blocks {
		if i == len(c.Blocks)-1 {
			break
		}
		blockRole := "user"
		if block.Role != "user" {
			blockRole = "assistant"	
		}
		messages = append(messages, openai.ChatCompletionMessage{
			Role:    blockRole,
			Content: strings.Join(block.Content, "\n"),
		})
	}
	
	response, err := client.CreateChatCompletion(context.Background(), openai.ChatCompletionRequest{
		Model:       model,
		Messages:    messages,
		Temperature: temperature,
	})
	if err != nil {
		return err
	}
	c.Blocks[len(c.Blocks)-1].Content = append(c.Blocks[len(c.Blocks)-1].Content, response.Choices[0].Message.Content)
	return nil
}
