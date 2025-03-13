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
			result.WriteString(block.Text())
		}
	}
	return result.String()
}


type Block struct {
	Role *Role
	Content strings.Builder
}


func (b *Block) Text() string {
	var result strings.Builder
	if b.Role.ToString() != "" {
		result.WriteString(b.Role.ToString() + "\n")
	}
	if b.Content.String() != "" {
		result.WriteString(strings.TrimRight(b.Content.String(), " \n") + "\n")
	}
	return result.String()
}

func ChatFromText(text string) *Chat {
	lines := strings.Split(text, "\n")
	blocks := []Block{Block{Role: &Role{Raw: "", Kind: KindMeta}, Content: strings.Builder{}}}
	for i, line := range lines {
		if LineIsRole(line) {
			blocks = append(blocks, Block{Role: RoleFromText(line), Content: strings.Builder{}})
		} else {
			if i == len(lines) - 1 {
				blocks[len(blocks)-1].Content.WriteString(line)
			} else if LineIsRole(lines[i+1]) {
				blocks[len(blocks)-1].Content.WriteString(line)
			} else {
				blocks[len(blocks)-1].Content.WriteString(line + "\n")
			}
		}
	}
	return &Chat{Blocks: blocks}
}

func (c *Chat) AddImpliedRoles() {
	// FIXME: brainstorm and other thinking blocks should be followed by an assistant block
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
			c.Blocks = append(c.Blocks, Block{Role: &Role{Raw: "assistant", Kind: KindAssistant}, Content: strings.Builder{}})
		}
	}
}
type SourcedParam struct {
	Source string
	Key string
	Value string
}

func (c *Chat) MergeParams(personaConfig *PersonaConfig, endpointDefaults map[string]string) map[string]SourcedParam {
	raw_params := map[string]SourcedParam{}
	for k, v := range endpointDefaults {
		raw_params[k] = SourcedParam{Source: "endpoint default", Key: k, Value: v}
	}
	lastBlock := c.Blocks[len(c.Blocks)-1]
	for k, v := range lastBlock.Role.Kwargs() {
		raw_params[k] = SourcedParam{Source: "last block kwarg", Key: k, Value: v}
	}
	for _, keyword := range lastBlock.Role.Keywords() {
		if personaParam, ok := (*personaConfig)[keyword]; ok {
			for k, v := range personaParam {
				raw_params[k] = SourcedParam{Source: "last block persona", Key: k, Value: v}
			}
		}
	}
	for _, block := range c.Blocks {
		if block.Role.Kind == KindMeta {
			for k, v := range block.Role.Kwargs() {
				raw_params[k] = SourcedParam{Source: "meta block", Key: k, Value: v}
			}
		}
	}
	return raw_params
}