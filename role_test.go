package main

import (
	"testing"
	"reflect"
)

func TestRole(t *testing.T) {
	tests := []struct {
		raw      string
		expectedKind Kind
		expectedKeywords []string
		kwargs   map[string]string
	}{
		{"#% user", KindUser, []string{"user"}, map[string]string{}},
		{"#% assistant", KindAssistant, []string{"assistant"}, map[string]string{}},
		{"#% brainstorm", KindAssistant, []string{"brainstorm"}, map[string]string{}},
		{"#% meta temperature=0.5", KindMeta, []string{"meta"}, map[string]string{"temperature": "0.5"}},
		{"#% unknown", KindUnknown, []string{"unknown"}, map[string]string{}},
	}

	for _, test := range tests {
		role := RoleFromText(test.raw)
		if role.Kind != test.expectedKind {
			t.Errorf("For raw text '%s', expected kind '%v' but got '%v'", test.raw, test.expectedKind, role.Kind)
		}
		if keywords := role.Keywords(); !reflect.DeepEqual(keywords, test.expectedKeywords) {
			t.Errorf("For raw text '%s', expected keywords '%v' but got '%v'", test.raw, test.expectedKeywords, keywords)
		}
		if kwargs := role.Kwargs(); !reflect.DeepEqual(kwargs, test.kwargs) {
			t.Errorf("For raw text '%s', expected kwargs '%v' but got '%v'", test.raw, test.kwargs, kwargs)
		}
	}
}
