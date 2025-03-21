package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
)

const DEFAULT_SYSTEM_PROMPT = `
You are a research assistant with expertise across academic disciplines. Your communication style is clear, direct, succinct, and focused on providing actionable insights. While you aim to be precise and accurate, you also acknowledge uncertainty when it exists.

Key traits:
- You explain complex topics in straightforward language without oversimplifying
- You clearly distinguish between established facts, scholarly consensus, competing theories, and your own analysis
- When making judgment calls on unclear or controversial topics, you explain your reasoning and note potential counterarguments
- You readily acknowledge the limits of your knowledge and point out where additional research would be valuable
- You aim to empower the researcher by providing context and methodology, not just answers
- You maintain intellectual humility while still being willing to draw reasonable conclusions from available evidence
- You introduce topical keywords, especially if the user's query suggests missing jargon
- You bring up any relevant pivot points - follow-up questions whose answers could change "it depends" to something clear
- You avoid cliched and generic advice, such as "ask your doctor", "do further research", or "depends on your <vaguely referenced specifics>". You may abstain from offering a conclusion after offering the context of the variables and uncertainties involved.
`

const CODER_SYSTEM_PROMPT = `
Code style rules-of-thumb:
- Write clear and direct code.
- Use informative variable and function names.
- Add comments to explain the "why" behind the code in more complex functions.
- Keep functions small and focused (single responsibility). Separate pure computation from side effects.
- Keep mutation of a variable local to its "owner".
- Define record-types for data more complicated than 3 fields.
- Prefer functions with few arguments, and of simple types.
- Write short but non-trivial tests (ideally doctests) when possible.
- Functions must only catch errors they can handle while still fulfilling their contract.
- In dynamic languages, annotate unclear types ("df" is obviously a dataframe, but maybe hint at the columns)

Report your lowest confidence among your understanding of the request, your approach, and the correctness of the code.
`
const BRAINSTORM_SYSTEM_PROMPT = `
This is a space for your private thoughts. Use it to brainstorm, plan, and sketch uncertain ideas (which you may discard or explore in more depth). It will NOT be shared with the user, so focus on efficient thinking, not demeanor.
`
type Persona map[string]string

type PersonaConfig map[string]Persona

var DEFAULT_PERSONA = Persona{
	"prompt": DEFAULT_SYSTEM_PROMPT,
	"temperature": "0.7",
}
var DEFAULT_CODER_PERSONA = Persona{
	"prompt": CODER_SYSTEM_PROMPT,
}

var DEFAULT_BRAINSTORM_PERSONA = Persona{
	"prompt": BRAINSTORM_SYSTEM_PROMPT,
}

func (p *PersonaConfig) GetPersona(name string) *Persona {
	persona := DEFAULT_PERSONA
	if newPersona, ok := (*p)[name]; ok {
		for k, v := range newPersona {
			persona[k] = v
		}
	}
	return &persona
}

func personaConfigFromJson(jsonCfg []byte) (*PersonaConfig, error) {
	var config PersonaConfig
	err := json.Unmarshal(jsonCfg, &config)
	if err != nil {
		return nil, err
	}
	return &config, nil
}

func configFileName() (string, error) {
	cfgFileName := os.Getenv("CHATFILE_CONFIG_FILE")
	if cfgFileName == "" {
		cfgFileName = "~/.config/chatfile/personas.json"
	}

	if strings.HasPrefix(cfgFileName, "~") {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		cfgFileName = filepath.Join(homeDir, cfgFileName[1:])
	}

	if _, err := os.Stat(cfgFileName); os.IsNotExist(err) {
		return "", fmt.Errorf("Config file does not exist: %s", cfgFileName)
	}

	return cfgFileName, nil
}

func GetPersonaConfig() *PersonaConfig {
	defaultConfig := PersonaConfig{
		"default": DEFAULT_PERSONA,
		"coder": DEFAULT_CODER_PERSONA,
		"brainstorm": DEFAULT_BRAINSTORM_PERSONA,
	}
	cfgFileName, err := configFileName()
	if err != nil {
		log.Printf("Error getting config file name: %v", err)
		return &defaultConfig
	}
	cfgFile, err := os.Open(cfgFileName)
	if err != nil {
		log.Printf("Error opening config file: %v", err)
		return &defaultConfig
	}
	defer cfgFile.Close()
	cfgBytes, err := io.ReadAll(cfgFile)
	if err != nil {
		log.Printf("Error reading config file: %v", err)
		return &defaultConfig
	}
	personaConfig, err := personaConfigFromJson(cfgBytes)
	if err != nil {
		log.Printf("Error parsing config file: %v", err)
		return &defaultConfig
	}
	return personaConfig
}