package main

import (
	"strings"
)

type Chat struct {
	Blocks []Block
}

func (c *Chat) Text() string {
	var result strings.Builder
	for _, block := range c.Blocks {
		if strings.TrimSpace(block.Text()) != "" {
			result.WriteString(block.Text() + "\n")
		}
	}
	return result.String()
}


type Block struct {
	Role *Role
	Content []string
}


func (b *Block) Text() string {
	var result strings.Builder
	if b.Role.ToString() != "" {
		result.WriteString(b.Role.ToString() + "\n")
	}
	result.WriteString(strings.Join(b.Content, "\n"))
	return result.String()
}

func ChatFromText(text string) *Chat {
	lines := strings.Split(text, "\n")
	blocks := []Block{Block{Role: &Role{Raw: "", Kind: KindMeta}, Content: []string{}}}
	for _, line := range lines {
		if LineIsRole(line) {
			blocks = append(blocks, Block{Role: RoleFromText(line), Content: []string{}})
		} else {
			blocks[len(blocks)-1].Content = append(blocks[len(blocks)-1].Content, line)
		}
	}
	return &Chat{Blocks: blocks}
}

func (c *Chat) AddImpliedRoles() {
	lastRoleKind := KindUser
	for i := range c.Blocks {
		block := &c.Blocks[i] // Get a reference to the block
		if block.Role.Kind == KindUnknown {
			if i == 0 {
				block.Role.Raw = "user"
				block.Role.Kind = KindUser
			} else if lastRoleKind == KindUser {
				block.Role.Kind = KindAssistant
			} else if lastRoleKind == KindAssistant {
				block.Role.Raw = "user"
				block.Role.Kind = KindUser
			}
		}
		if block.Role.Kind != KindMeta {
			lastRoleKind = block.Role.Kind
		}
	}

	if len(c.Blocks) > 0 {
		lastBlock := &c.Blocks[len(c.Blocks)-1]
		if lastBlock.Role.Kind == KindUser {
			c.Blocks = append(c.Blocks, Block{Role: &Role{Raw: "assistant", Kind: KindAssistant}, Content: []string{}})
		}
	}
}