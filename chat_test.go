package main

import (
	"testing"
)

func TestAddImpliedRoles(t *testing.T) {
	// Template content for foo.chat
	chatContent := `#%user
Hello, how are you?
#%assistant
I'm good, thank you! How can I help you today?
#%user
Can you tell me a joke?
`

	chat := ChatFromText(chatContent)
	chat.AddImpliedRoles()

	expectedRoles := []string{"user", "assistant", "user", "assistant"}
	for i, block := range chat.Blocks {
		if block.Role != expectedRoles[i] {
			t.Errorf("Expected role %s but got %s at block %d", expectedRoles[i], block.Role, i)
		}
	}
	expectedText := `#%user
Hello, how are you?
#%assistant
I'm good, thank you! How can I help you today?
#%user
Can you tell me a joke?

#%assistant

`
	if chat.Text() != expectedText {
		t.Errorf("Expected text %s but got %s", expectedText, chat.Text())
	}
}

