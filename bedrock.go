package main

import (
	"context"
	"encoding/json"
	"os"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime/types"
	"log/slog"
)

var DEFAULT_BEDROCK_PARAMS = map[string]string{
	"model": "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
	"temperature": "0.7",
	"anthropic_version": "bedrock-2023-05-31",
	"max_tokens": "4096",
	"stop_sequences": "[]",
	"top_p": "0.9",
	"top_k": "250",
	"prompt": DEFAULT_SYSTEM_PROMPT,
}

func AWSConnectionIsPossible() bool {
	os.Setenv("AWS_EC2_METADATA_DISABLED", "true")
    cfg, err := config.LoadDefaultConfig(context.TODO())
    if err != nil {
        return false
    }

    _, err = cfg.Credentials.Retrieve(context.TODO())
    return err == nil
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


func (c *Chat) BedrockConversation(personaConfig *PersonaConfig) (*BedrockConversation, string) {
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
	params := c.MergeParams(personaConfig, DEFAULT_BEDROCK_PARAMS)
	
	maxTokens, err := strconv.Atoi(params["max_tokens"].Value)
	slog.Info("Using max_tokens", "source", params["max_tokens"].Source)
	if err != nil {
		slog.Error("Error parsing max_tokens", "error", err)
		os.Exit(1)
	}
	temperature, err := strconv.ParseFloat(params["temperature"].Value, 64)
	slog.Info("Using temperature", "source", params["temperature"].Source)
	if err != nil {
		slog.Error("Error parsing temperature", "error", err)
		os.Exit(1)
	}
	topP, err := strconv.ParseFloat(params["top_p"].Value, 64)
	slog.Info("Using top_p", "source", params["top_p"].Source)
	if err != nil {
		slog.Error("Error parsing top_p", "error", err)
		os.Exit(1)
	}
	topK, err := strconv.Atoi(params["top_k"].Value)
	slog.Info("Using top_k", "source", params["top_k"].Source)
	if err != nil {
		slog.Error("Error parsing top_k", "error", err)
		os.Exit(1)
	}
	slog.Info("Using anthropic_version", "source", params["anthropic_version"].Source)
	slog.Info("Using prompt", "source", params["prompt"].Source)
	slog.Info("Using model", "source", params["model"].Source)
	return &BedrockConversation{
		Messages: messages,
		MaxTokens: int32(maxTokens),
		Temperature: temperature,
		AnthropicVersion: params["anthropic_version"].Value,
		TopP: topP,
		TopK: int32(topK),
		StopSequences: []string{},
		SystemPrompt: params["prompt"].Value,
	}, params["model"].Value
}

func (c *Chat) BedrockAPIComplete(personaConfig *PersonaConfig, ch chan<- string) {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		slog.Error("Error loading AWS config", "error", err)
		os.Exit(1)
	}

	bedrockClient := bedrockruntime.NewFromConfig(cfg)
	conversation, model := c.BedrockConversation(personaConfig)
	body, err := json.Marshal(conversation)
	if err != nil {
		slog.Error("Error marshalling conversation", "error", err)
		os.Exit(1)
	}

	response, err := bedrockClient.InvokeModelWithResponseStream(context.TODO(), &bedrockruntime.InvokeModelWithResponseStreamInput{
		Body: body,
		ModelId: aws.String(model),
		ContentType: aws.String("application/json"),
	})
	
	if err != nil {
		slog.Error("Error invoking model with response stream", "error", err)
		os.Exit(1)
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
				slog.Warn("Error unmarshalling response chunk", "error", err)
				continue
			}

			if delta.Delta.Type == "text_delta" {
				ch <- delta.Delta.Text
			}
		case *types.UnknownUnionMember:
			slog.Info("Unknown tag", "tag", v.Tag)
		default:
			slog.Info("Union is nil or unknown type", "type", v)
		}
	}
	close(ch)
}
