package main

import (
	"context"
	"errors"
	"io"
	"os"
	"strconv"
	"github.com/sashabaranov/go-openai"
	"log/slog"
)

var DEFAULT_OPENAI_PARAMS = map[string]string{
	"model":       "gpt-4o-mini",
	"temperature": "0.7",
}

func (c *Chat) OpenAIMessages() []openai.ChatCompletionMessage {
	messages := []openai.ChatCompletionMessage{}
	for _, block := range c.Blocks {
		role := "user"
		if block.Role.Kind == KindUser {
			role = "user"
		} else if block.Role.Kind == KindAssistant && block.Content.String() != "" {
			role = "assistant"
		} else {
			continue
		}

		messages = append(messages, openai.ChatCompletionMessage{
			Role:    role,
			Content: block.Content.String(),
		})
	}
	return messages
}

func (c *Chat) OpenAICompletionRequest(personaConfig *PersonaConfig) openai.ChatCompletionRequest {
	params := c.MergeParams(personaConfig, DEFAULT_OPENAI_PARAMS)
	slog.Info("Using prompt", "source", params["prompt"].Source)
	messages := []openai.ChatCompletionMessage{
		openai.ChatCompletionMessage{
			Role:    "developer",
			Content: params["prompt"].Value,
		},
	}
	messages = append(messages, c.OpenAIMessages()...)

	temperature, err := strconv.ParseFloat(params["temperature"].Value, 32)
	slog.Info("Using temperature", "source", params["temperature"].Source)
	if err != nil {
		slog.Error("Error parsing temperature", "error", err)
		os.Exit(1)
	}
	slog.Info("Using model", "source", params["model"].Source)
	return openai.ChatCompletionRequest{
		Model:       params["model"].Value,
		Temperature: float32(temperature),
		Messages:    messages,
		Stream:      true,
	}
}

func (c *Chat) OpenAIAPIComplete(personaConfig *PersonaConfig, ch chan<- string) {
	client := openai.NewClient(os.Getenv("OPENAI_API_KEY"))

	request := c.OpenAICompletionRequest(personaConfig)
	stream, err := client.CreateChatCompletionStream(context.Background(), request)
	if err != nil {
		slog.Error("Error creating chat completion stream", "error", err)
		os.Exit(1)
	}
	for {
		response, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			close(ch)
			return
		} else if err != nil {
			slog.Error("Error receiving stream", "error", err)
			os.Exit(1)
		}
		ch <- response.Choices[0].Delta.Content
	}
}
