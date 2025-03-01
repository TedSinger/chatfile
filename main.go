package main

import (
	// "fmt"
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
	err = chat.OpenAIAPIComplete("gpt-4o-mini", 0.7)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	os.WriteFile(os.Args[1], []byte(chat.Text()), 0744)
}
