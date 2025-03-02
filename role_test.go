package main

import (
	"testing"
)

func TestPersona(t *testing.T) {
	tests := []struct {
		raw      string
		expected string
	}{
		{"#% user", "default"},
		{"#% assistant", "default"},
		{"#% brainstorm", "brainstorm"},
		{"#% meta", "default"},
		{"#% unknown", "default"},
	}

	for _, test := range tests {
		role := RoleFromText(test.raw)
		if persona := role.Persona(); persona != test.expected {
			t.Errorf("For raw text '%s', expected persona '%s' but got '%s'", test.raw, test.expected, persona)
		}
	}
}
