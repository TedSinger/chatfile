package main

import (
	"errors"
	"io"
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
	stream, err := chat.OpenAIAPIComplete()
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	outfile, err := os.OpenFile(os.Args[1], os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	defer outfile.Close()
	lastBlock := &chat.Blocks[len(chat.Blocks)-1]
	for {
		response, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			break
		} else if err != nil {
			log.Fatalf("Error: %v", err)
		}
		newContent := response.Choices[0].Delta.Content
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
