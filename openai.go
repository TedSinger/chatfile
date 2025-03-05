package main
import (
	"context"
	"errors"
	"io"
	"log"
	"os"
	"strconv"
	"github.com/sashabaranov/go-openai"
)

var DEFAULT_OPENAI_PARAMS = map[string]string{
	"model": "gpt-4o-mini",
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

func (c *Chat) OpenAICompletionRequest() openai.ChatCompletionRequest {
	params := c.Params(DEFAULT_OPENAI_PARAMS)
	messages := []openai.ChatCompletionMessage{
		openai.ChatCompletionMessage{
			Role:    "developer",
			Content: PROMPTS_BY_PERSONA[params["persona"]],
		},
	}
	messages = append(messages, c.OpenAIMessages()...)

	temperature, err := strconv.ParseFloat(params["temperature"], 32)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	return openai.ChatCompletionRequest{
		Model:       params["model"],
		Temperature: float32(temperature),
		Messages:    messages,
		Stream:      true,
	}
}

func (c *Chat) OpenAIAPIComplete(ch chan<- string) {
	client := openai.NewClient(os.Getenv("OPENAI_API_KEY"))

	request := c.OpenAICompletionRequest()
	stream, err := client.CreateChatCompletionStream(context.Background(), request)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	for {
		response, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			close(ch)
			return
		} else if err != nil {
			log.Fatalf("Error: %v", err)
		}
		ch <- response.Choices[0].Delta.Content
	}
}

