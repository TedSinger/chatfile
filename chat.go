package main

import "strings"

type Chat struct {
	Blocks []Block
}

func (c *Chat) Text() string {
	var result strings.Builder
	for _, block := range c.Blocks {
		result.WriteString(block.Text())
	}
	return result.String()
}


type Block struct {
	Role string
	Content []string
}

func (b *Block) Text() string {
	var result strings.Builder
	result.WriteString("#%" + b.Role + "\n")
	result.WriteString(strings.Join(b.Content, "\n") + "\n")
	return result.String()
}

func ChatFromText(text string) *Chat {
	lines := strings.Split(text, "\n")
	blocks := []Block{}
	for _, line := range lines {
		if strings.HasPrefix(line, "#%") {
			blocks = append(blocks, Block{Role: strings.TrimSpace(line[2:]), Content: []string{}})
		} else if len(blocks) > 0 {
			blocks[len(blocks)-1].Content = append(blocks[len(blocks)-1].Content, line)
		}
	}
	return &Chat{Blocks: blocks}
}

func (c *Chat) AddImpliedRoles() {
	lastRole := ""
	for i, block := range c.Blocks {
		if block.Role == "" {
			if i == 0 {
				block.Role = "user"
			} else if lastRole == "user" {
				block.Role = "assistant"
			} else {
				block.Role = "user"
			}
		}
		lastRole = block.Role
	}
	if len(c.Blocks) > 0 && c.Blocks[len(c.Blocks)-1].Role == "user" {
		c.Blocks = append(c.Blocks, Block{Role: "assistant", Content: []string{}})
	}
}