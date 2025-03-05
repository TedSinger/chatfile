package main
import (
	"context"
	"log"
	"os"
	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

func (c *Chat) ToAnthropicMessages() []anthropic.MessageParam {
	messages := []anthropic.MessageParam{}
	for _, block := range c.Blocks {
		if block.Role.Kind == KindUser {
			messages = append(messages, anthropic.NewUserMessage(anthropic.NewTextBlock(block.Content.String())))
		} else if block.Role.Kind == KindAssistant && block.Content.String() != "" {
			messages = append(messages, anthropic.NewAssistantMessage(anthropic.NewTextBlock(block.Content.String())))
		}
	}
	return messages
}

func (c *Chat) AnthropicChatCompletionRequest() anthropic.MessageNewParams {
	return anthropic.MessageNewParams{
		Model: anthropic.F("claude-3-5-sonnet-20240620"),
		MaxTokens: anthropic.F(int64(4096)),
		Messages: anthropic.F(c.ToAnthropicMessages()),
	}
}

func (c *Chat) AnthropicAPIComplete(ch chan<- string) {
	client := anthropic.NewClient(option.WithAPIKey(os.Getenv("ANTHROPIC_API_KEY")))
	request := c.AnthropicChatCompletionRequest()
	stream := client.Messages.NewStreaming(context.Background(), request)
	if stream.Err() != nil {
		log.Fatalf("Error: %v", stream.Err())
	}
	for stream.Next() {
		event := stream.Current()
		switch delta := event.Delta.(type) {
			case anthropic.ContentBlockDeltaEventDelta:
				if delta.Text != "" {
					ch <- delta.Text
				}
		}
	}
	close(ch)
}