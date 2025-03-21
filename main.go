package main

import (
	"log"
	"os"
)

func preferredEndpoint(c *Chat, personaConfig *PersonaConfig, stream chan string) func() {
	if AWSConnectionIsPossible() {
		log.Println("Using Bedrock")
		return func() { c.BedrockAPIComplete(personaConfig, stream) }
	} else if os.Getenv("ANTHROPIC_API_KEY") != "" {
		log.Println("Using Anthropic")
		return func() { c.AnthropicAPIComplete(personaConfig, stream) }
	} else if os.Getenv("OPENAI_API_KEY") != "" {
		log.Println("Using OpenAI")
		return func() { c.OpenAIAPIComplete(personaConfig, 	stream) }
	}
	return nil
}

func main() {
	personaConfig := GetPersonaConfig()
	
	content, err := os.ReadFile(os.Args[1])
	if err != nil {
		log.Fatalf("Error reading file: %v", err)
	}
	chat := ChatFromText(string(content))
	chat.AddImpliedRoles()
	os.WriteFile(os.Args[1], []byte(chat.Text()), 0744)
	stream := make(chan string)
	endpoint := preferredEndpoint(chat, personaConfig, stream)
	if endpoint == nil {
		log.Fatalf("No API key found")
	}
	go endpoint()
	outfile, err := os.OpenFile(os.Args[1], os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	defer outfile.Close()
	lastBlock := &chat.Blocks[len(chat.Blocks)-1]
	for newContent := range stream {
		lastBlock.Content.WriteString(newContent)
		_, err = outfile.WriteString(newContent)
		if err != nil {
			log.Fatalf("Error: %v", err)
		}
		err = outfile.Sync()
		if err != nil {
			log.Fatalf("Error: %v", err)
		}
	}
}
