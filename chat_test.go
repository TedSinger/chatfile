package main

import (
	"testing"
	"strings"
)

func TestAddImpliedRoles(t *testing.T) {
	// Template content for foo.chat
	chatContent := `#%user
Hello, how are you?
#%
I'm good, thank you! How can I help you today?
#%user
Can you tell me a joke?
`

	chat := ChatFromText(chatContent)
	chat.AddImpliedRoles()

	expectedRoles := []Kind{KindMeta, KindUser, KindAssistant, KindUser, KindAssistant}
	if len(chat.Blocks) != len(expectedRoles) {
		t.Errorf("Expected %d blocks but got %d", len(expectedRoles), len(chat.Blocks))
	}
	for i, block := range chat.Blocks {
		if block.Role.Kind != expectedRoles[i] {
			t.Errorf("Expected role %s but got %s at block %d", expectedRoles[i].ToString(), block.Role.Raw, i)
		}
	}
	expectedText := `#% user
Hello, how are you?
#% assistant
I'm good, thank you! How can I help you today?
#% user
Can you tell me a joke?
#% assistant

`
	lines := strings.Split(chat.Text(), "\n")
	expectedLines := strings.Split(expectedText, "\n")
	if len(lines) != len(expectedLines) {
		t.Errorf("Expected %d lines but got %d", len(expectedLines), len(lines))
	}
	for i := range lines {
		if lines[i] != expectedLines[i] {
			t.Errorf("Expected line %d to be %s but got %s", i, expectedLines[i], lines[i])
		}
	}
}

