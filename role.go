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

var KnownPersonas = []string{
	"coder",
	"brainstorm",
	"default",
}

type Role struct {
	Raw string
    Kind Kind
}

func (r *Role) Persona() string {
	for _, persona := range KnownPersonas {
		if strings.Contains(r.Raw, persona) {
			return persona
		}
	}
	return "default"
}

func (r *Role) Kwargs() map[string]string {
	kwargs := make(map[string]string)
	for _, arg := range strings.Split(r.Raw, " ") {
		if strings.Contains(arg, "=") {
			kwargs[strings.Split(arg, "=")[0]] = strings.Split(arg, "=")[1]
		}
	}
	return kwargs
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
	if r.Raw == "" {
		return ""
	} else if r.Persona() != "default" {
		return "#% " + r.Persona()
	} else {
		return "#% " + r.Kind.ToString()
	}
}
