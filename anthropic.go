package main
import (
	"context"
	"log"
	"os"
	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)


func (c *Chat) AnthropicChatCompletionRequest() anthropic.MessageNewParams {
	model := "claude-3-5-sonnet-20240620"
	messages := []anthropic.MessageParam{}
	for _, block := range c.Blocks {
		if block.Role.Kind == KindUser {
			messages = append(messages, anthropic.NewUserMessage(anthropic.NewTextBlock(block.Content.String())))
		} else if block.Role.Kind == KindAssistant && block.Content.String() != "" {
			messages = append(messages, anthropic.NewAssistantMessage(anthropic.NewTextBlock(block.Content.String())))
		}
		if block.Role.Kwargs()["model"] != "" {
			model = block.Role.Kwargs()["model"]
		}
	}
	return anthropic.MessageNewParams{
		Model: anthropic.F(model),
		MaxTokens: anthropic.F(int64(4096)),
		Messages: anthropic.F(messages),
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