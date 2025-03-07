package main

import (
	"log"
	"os"
)
func main() {
	content, err := os.ReadFile(os.Args[1])
	if err != nil {
		log.Fatalf("Error reading file: %v", err)
	}
	chat := ChatFromText(string(content))
	chat.AddImpliedRoles()
	os.WriteFile(os.Args[1], []byte(chat.Text()), 0744)
	stream := make(chan string)
	go func() {
		chat.BedrockAPIComplete(stream)
	}()
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
