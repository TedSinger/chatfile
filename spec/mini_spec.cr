require "./spec_helper"
require "../src/mini"

describe Mini do
  it "parses basic key-value pairs" do
    Mini.parse(<<-INI
    [global]
    prompt = no matter what, sneak the word 'global' into your response
    INI
    ).should eq({
      "global" => {"prompt" => "no matter what, sneak the word 'global' into your response"},
    })
  end

  it "handles multiple sections" do
    Mini.parse(<<-INI
    [global]
    prompt = test
    
    [provider:openai]
    model = gpt-4
    temperature = 0.7
    INI
    ).should eq({
      "global"          => {"prompt" => "test"},
      "provider:openai" => {
        "model"       => "gpt-4",
        "temperature" => "0.7",
      },
    })
  end

  it "handles empty sections" do
    Mini.parse(<<-INI
    [section1]
    
    [section2]
    key = value
    INI
    ).should eq({
      "section1" => {} of String => String,
      "section2" => {"key" => "value"},
    })
  end

  it "handles multiline values" do
    Mini.parse(<<-INI
    [global]
    prompt = first line
      second line
      third line
    key2 = value2
    INI
    ).should eq({
      "global" => {
        "prompt" => "first line\nsecond line\nthird line",
        "key2"   => "value2",
      },
    })
  end

  it "ignores comments" do
    Mini.parse(<<-INI
    ; This is a comment
    [section]
    # so is this
    key = value
    INI
    ).should eq({
      "section" => {"key" => "value"},
    })
  end

  it "raises on malformed input" do
    expect_raises(Exception, "Invalid section header") do
      Mini.parse("[bad section")
    end

    expect_raises(Exception) do
      Mini.parse("key = value")
    end

    expect_raises(Exception) do
      Mini.parse(<<-INI
      [section]
      invalid line
      INI
      )
    end
  end
  it "allows empty values" do
    Mini.parse(<<-INI
    [section]
    key =
    INI
    ).should eq({"section" => {"key" => ""}})
  end
end
