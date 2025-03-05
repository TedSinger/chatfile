package main
import (
	"context"
	"fmt"
	"errors"
	"io"
	"log"
	"os"
	"strconv"
	"github.com/sashabaranov/go-openai"
)

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

var DEFAULT_PARAMS = map[string]interface{}{
	"model": "gpt-4o-mini",
	"temperature": float32(0.7),
}

func updateDefaultParams(kwargs map[string]string) {
	for k, v := range kwargs {
		switch k {
		case "model":
			DEFAULT_PARAMS["model"] = v
		case "temperature":
			temperature, err := strconv.ParseFloat(v, 32)
			if err != nil {
				continue
			}
			DEFAULT_PARAMS["temperature"] = float32(temperature)
		}
	}
}

func (c *Chat) OpenAICompletionRequest() openai.ChatCompletionRequest {
	messages := []openai.ChatCompletionMessage{}
	messages = append(messages, openai.ChatCompletionMessage{
		Role:    "developer",
		Content: PROMPTS_BY_PERSONA["default"],
	})
	for i, block := range c.Blocks {
		blockRole := "user"
		if block.Role.Kind == KindAssistant {
			blockRole = "assistant"	
			fmt.Println("Setting persona to " + block.Role.Persona())
			fmt.Println(block.Role.Raw)
			messages[0].Content = PROMPTS_BY_PERSONA[block.Role.Persona()]
			updateDefaultParams(block.Role.Kwargs())
		} else if block.Role.Kind == KindUser {
			blockRole = "user"
		} else if block.Role.Kind == KindMeta {
			updateDefaultParams(block.Role.Kwargs())
			continue
		} else {
			panic("Unknown block role: " + block.Role.Raw)
		}
		if i == len(c.Blocks)-1 {
			break
		}
		messages = append(messages, openai.ChatCompletionMessage{
			Role:    blockRole,
			Content: block.Content.String(),
		})
	}
	return openai.ChatCompletionRequest{
		Model:       DEFAULT_PARAMS["model"].(string),
		Temperature: DEFAULT_PARAMS["temperature"].(float32),
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

