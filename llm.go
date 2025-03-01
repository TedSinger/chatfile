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



func (c *Chat) OpenAICompletionRequest() openai.ChatCompletionRequest {
	messages := []openai.ChatCompletionMessage{}
	DEFAULT_PARAMS := map[string]interface{}{
		"model": "gpt-4o-mini",
		"temperature": 0.7,
		"prompt": DEFAULT_SYSTEM_PROMPT,
	}
	messages = append(messages, openai.ChatCompletionMessage{
		Role:    "developer",
		Content: DEFAULT_PARAMS["prompt"].(string),
	})
	for i, block := range c.Blocks {
		if i == len(c.Blocks)-1 {
			break
		}
		blockRole := "user"
		if block.Role.Kind == KindAssistant {
			blockRole = "assistant"	
			if block.Role.Raw == "coder" {
				messages[0].Content = CODER_SYSTEM_PROMPT
			}
		} else if block.Role.Kind == KindUser {
			blockRole = "user"
		} else if block.Role.Kind == KindMeta {
			continue
		} else {
			panic("Unknown block role: " + block.Role.Raw)
		}
		messages = append(messages, openai.ChatCompletionMessage{
			Role:    blockRole,
			Content: strings.Join(block.Content, "\n"),
		})
	}
	return openai.ChatCompletionRequest{
		Model:       DEFAULT_PARAMS["model"].(string),
		Temperature: DEFAULT_PARAMS["temperature"].(float32),
		Messages:    messages,
	}
}

func (c *Chat) OpenAIAPIComplete() error {
	client := openai.NewClient(os.Getenv("OPENAI_API_KEY"))

	request := c.OpenAICompletionRequest()
	response, err := client.CreateChatCompletion(context.Background(), request)
	if err != nil {
		return err
	}
	c.Blocks[len(c.Blocks)-1].Content = append(c.Blocks[len(c.Blocks)-1].Content, response.Choices[0].Message.Content)
	return nil
}
