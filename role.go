package main
import "strings"

type Kind int

const (
	KindUser Kind = iota
	KindAssistant
	KindMeta
    KindUnknown
)

func (k Kind) ToString() string {
	return []string{"user", "assistant", "meta", "unknown"}[k]
}

func KindFromText(text string) Kind {
    text = strings.TrimSpace(text[2:])
	if strings.HasPrefix(text, "user") {
		return KindUser
	} else if strings.HasPrefix(text, "assistant") {
		return KindAssistant
	} else if strings.HasPrefix(text, "meta") {
		return KindMeta
	} else {
        return KindUnknown
    }
}
type Role struct {
	Raw string
    Kind Kind
}

func RoleFromText(text string) *Role {
	return &Role{
		Raw: text,
		Kind: KindFromText(text),
	}
}

func LineIsRole(line string) bool {
	return strings.HasPrefix(line, "#%")
}

func (r *Role) ToString() string {
	return "#% " + r.Kind.ToString()
}
