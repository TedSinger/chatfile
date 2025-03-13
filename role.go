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

func (r *Role) Kwargs() map[string]string {
	kwargs := make(map[string]string)
	for _, arg := range strings.Split(r.Raw, " ") {
		if strings.Contains(arg, "=") {
			kwargs[strings.Split(arg, "=")[0]] = strings.Split(arg, "=")[1]
		}
	}
	return kwargs
}

func (r *Role) Keywords() []string {
	keywords := []string{}
	for _, arg := range strings.Split(r.Raw, " ") {
		if !strings.Contains(arg, "=") && arg != "#%" {
			keywords = append(keywords, arg)
		}
	}
	return keywords
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
	}
	parts := []string{"#%", r.Kind.ToString()}
	for _, keyword := range r.Keywords() {
		if keyword != r.Kind.ToString() {
			parts = append(parts, keyword)
		}
	}
	for key, value := range r.Kwargs() {
		parts = append(parts, key + "=" + value)
	}
	return strings.Join(parts, " ")
}
