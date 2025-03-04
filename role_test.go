package main

import (
	"testing"
	"reflect"
)

func TestPersona(t *testing.T) {
	tests := []struct {
		raw      string
		expected string
		kwargs   map[string]string
	}{
		{"#% user", "default", map[string]string{}},
		{"#% assistant", "default", map[string]string{}},
		{"#% brainstorm", "brainstorm", map[string]string{}},
		{"#% meta temperature=0.5", "default", map[string]string{"temperature": "0.5"}},
		{"#% unknown", "default", map[string]string{}},
	}

	for _, test := range tests {
		role := RoleFromText(test.raw)
		if persona := role.Persona(); persona != test.expected {
			t.Errorf("For raw text '%s', expected persona '%s' but got '%s'", test.raw, test.expected, persona)
		}
		if kwargs := role.Kwargs(); !reflect.DeepEqual(kwargs, test.kwargs) {
			t.Errorf("For raw text '%s', expected kwargs '%v' but got '%v'", test.raw, test.kwargs, kwargs)
		}
	}
}
