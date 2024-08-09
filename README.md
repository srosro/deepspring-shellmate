<img src="https://uploads-ssl.webflow.com/667dbe7f3b1fec453d3524ce/66b65ae4c5cae6f59293e078_sm_logo_color.png" width="240">
Shellmate is a Mac Terminal companion that gives you dynamic error correction and guidance seamlessly (keeping you in your Terminal and in the flow).


## Features
**Ask questions:** Ask ShellMate with natural text about your Terminal context.

**Detect & Fix errors:** ShellMate uses your terminal history to detect & fix errors and predict which commands you’ll need next.

**Highlight text:** Highlight text to call ShellMate's "attention" to a particular issue. 

**Never switch focus:** You’ll never need to leave your Terminal. Use the `sm` shortcut to ask questions and insert AI-generated suggestions straight into your active console. 
Example: `sm “find a file?”`


## Demo
<img src="https://uploads-ssl.webflow.com/667dbe7f3b1fec453d3524ce/66915dd493cf1d1664d9a616_sm_hero_2%20(1).gif">


## Installation Instructions

### From DMG
Download here: https://www.deepspring.ai/shellmate

### From source
```bash
git clone git@github.com:srosro/deepspring-shellmate.git
```

To run from source, open and build the repository in Xcode.

### API Key Setup
This app includes a free-tier usage feature, but the API key has been deleted. To use it, you'll need to update the hardcoded variable with your own API key at line 16 in the `Utils.swift` file located at `ShellMate/Helpers/Utils.swift` in the repository.

```swift
func getHardcodedOpenAIAPIKey() -> String {
    return "your-openai-api-key-here"
}
```

Alternatively, you can add your OpenAI API key directly in the settings or permissions view, which allows the key to be used without hardcoding it.

## Contributing
ShellMate is an open-source project and we welcome contributions from the community. 

If you'd like to contribute, please fork the repository and make changes as you'd like. Pull requests are warmly welcome.

**Our contributors**

[<img src="https://uploads-ssl.webflow.com/667dbe7f3b1fec453d3524ce/66b51b4ddae154eba5cf6818_contributors.png" width="160">](https://github.com/srosro/deepspring-shellmate/graphs/contributors)


## License
This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.