package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime/types"
)

var DEFAULT_BEDROCK_PARAMS = map[string]string{
	"model": "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
	"temperature": "0.7",
	"anthropic_version": "bedrock-2023-05-31",
	"max_tokens": "4096",
	"stop_sequences": "[]",
	"top_p": "0.9",
	"top_k": "250",
	"persona": DEFAULT_SYSTEM_PROMPT,
}

type BedrockMessage struct {
	Role string `json:"role"`
	Content []BedrockContent `json:"content"`
}

type BedrockContent struct {
	Text string `json:"text"`
	Type string `json:"type"`
}

type BedrockConversation struct {
	Messages []BedrockMessage `json:"messages"`
	MaxTokens int32 `json:"max_tokens"`
	Temperature float64 `json:"temperature"`
	AnthropicVersion string `json:"anthropic_version"`
	TopP float64 `json:"top_p"`
	TopK int32 `json:"top_k"`
	StopSequences []string `json:"stop_sequences"`
	SystemPrompt string `json:"system"`
}


func (c *Chat) BedrockConversation() (*BedrockConversation, string) {
	messages := []BedrockMessage{}
	for i, block := range c.Blocks {
		bedrockRole := ""
		if block.Role.Kind == KindUser {
			bedrockRole = "user"
		} else if block.Role.Kind == KindAssistant {
			bedrockRole = "assistant"
		}
		if bedrockRole == "" || i == len(c.Blocks)-1 {
			continue
		}
		messages = append(messages, BedrockMessage{
			Role: bedrockRole,
			Content: []BedrockContent{BedrockContent{Text: block.Content.String(), Type: "text"}},
		})
	}

	params := c.Params(DEFAULT_BEDROCK_PARAMS)
	maxTokens, err := strconv.Atoi(params["max_tokens"])
	if err != nil {
		log.Fatal(err)
	}
	temperature, err := strconv.ParseFloat(params["temperature"], 64)
	if err != nil {
		log.Fatal(err)
	}
	topP, err := strconv.ParseFloat(params["top_p"], 64)
	if err != nil {
		log.Fatal(err)
	}
	topK, err := strconv.Atoi(params["top_k"])
	if err != nil {
		log.Fatal(err)
	}
	return &BedrockConversation{
		Messages: messages,
		MaxTokens: int32(maxTokens),
		Temperature: temperature,
		AnthropicVersion: params["anthropic_version"],
		TopP: topP,
		TopK: int32(topK),
		StopSequences: []string{},
		SystemPrompt: PROMPTS_BY_PERSONA[params["persona"]],
	}, params["model"]
}

func (c *Chat) BedrockAPIComplete(ch chan<- string) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal(err)
	}

	bedrockClient := bedrockruntime.NewFromConfig(cfg)
	conversation, model := c.BedrockConversation()
	body, err := json.Marshal(conversation)
	if err != nil {
		log.Fatal(err)
	}

	response, err := bedrockClient.InvokeModelWithResponseStream(context.TODO(), &bedrockruntime.InvokeModelWithResponseStreamInput{
		Body: body,
		ModelId: aws.String(model),
		ContentType: aws.String("application/json"),
	})
	
	if err != nil {
		log.Fatal(err)
	}

	for event := range response.GetStream().Events() {
		switch v := event.(type) {
		case *types.ResponseStreamMemberChunk:
			//{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" object with"}}
			var delta struct {
				Type  string `json:"type"`
				Index int    `json:"index"`
				Delta struct {
					Type string `json:"type"`
					Text string `json:"text"`
				} `json:"delta"`
			}

			err := json.Unmarshal(v.Value.Bytes, &delta)
			if err != nil {
				log.Printf("Error unmarshalling response chunk: %v\n", err)
				continue
			}

			if delta.Delta.Type == "text_delta" {
				ch <- delta.Delta.Text
			}
		case *types.UnknownUnionMember:
			fmt.Println("unknown tag:", v.Tag)
		default:
			fmt.Println("union is nil or unknown type", v)
		}
	}
	close(ch)
}
