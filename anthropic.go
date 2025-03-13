package main

import (
	"context"
	"os"
	"strconv"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
	"log/slog"
)

var DEFAULT_ANTHROPIC_PARAMS = map[string]string{
	"model":       "claude-3-5-sonnet-20240620",
	"temperature": "0.7",
	"max_tokens":  "4096",
}

func (c *Chat) AnthropicMessages() []anthropic.MessageParam {
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

func (c *Chat) AnthropicChatCompletionRequest(personaConfig *PersonaConfig) anthropic.MessageNewParams {
	messages := c.AnthropicMessages()
	params := c.MergeParams(personaConfig, DEFAULT_ANTHROPIC_PARAMS)
	prompt := params["prompt"].Value
	slog.Info("Using prompt", "source", params["prompt"].Source)
	temperature, err := strconv.ParseFloat(params["temperature"].Value, 64)
	if err != nil {
		slog.Error("Error parsing temperature", "error", err)
		os.Exit(1)
	}
	slog.Info("Using temperature", "source", params["temperature"].Source)
	maxTokens, err := strconv.Atoi(params["max_tokens"].Value)
	if err != nil {
		slog.Error("Error parsing max_tokens", "error", err)
		os.Exit(1)
	}
	slog.Info("Using max_tokens", "source", params["max_tokens"].Source)
	system := []anthropic.TextBlockParam{
		anthropic.NewTextBlock(prompt),
	}
	slog.Info("Using model", "source", params["model"].Source)
	return anthropic.MessageNewParams{
		Model:       anthropic.F(params["model"].Value),
		MaxTokens:   anthropic.F(int64(maxTokens)),
		Messages:    anthropic.F(messages),
		Temperature: anthropic.F(temperature),
		System:      anthropic.F(system),
	}
}

func (c *Chat) AnthropicAPIComplete(personaConfig *PersonaConfig, ch chan<- string) {
	client := anthropic.NewClient(option.WithAPIKey(os.Getenv("ANTHROPIC_API_KEY")))
	request := c.AnthropicChatCompletionRequest(personaConfig)
	stream := client.Messages.NewStreaming(context.Background(), request)
	if stream.Err() != nil {
		slog.Error("Error creating stream", "error", stream.Err())
		os.Exit(1)
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