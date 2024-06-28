# ShellMate
<img src="https://github.com/srosro/shellbuddy/assets/95421/697e8c2f-95cd-4379-b02c-fa9d406243ff" width="300">

## Installation Instructions
```bash
git clone git@github.com:srosro/shellbuddy.git
```

Open the project in Xcode, build it, and then you will be able to run it.



## Setting Up OPENAI_API_KEY in Xcode
To integrate OpenAI API calls in ShellMate, you need to set up an `OPENAI_API_KEY` environment variable in Xcode. Follow these steps:

1. In Xcode, navigate to the top menu and click on `Product`.
2. Select `Scheme` then `Edit Scheme`.
3. In the sidebar of the scheme editor, select `Run`.
4. Go to the `Arguments` tab.
5. Under `Environment Variables`, click the `+` button to add a new variable.
6. Enter `OPENAI_API_KEY` as the name and your OpenAI API key as the value.
7. Close the scheme editor to save your changes.

## Build in Xcode
![Setting Up OPENAI_API_KEY](examples/openai_key_setup.png)


## Example Usage
Open a new terminal and work as you normally would. You now have a buddy offering you tips :)

![Asking Questions](examples/asking_questions.png)

By following these instructions, you can securely incorporate the OpenAI API into your Xcode project, enabling ShellMate to utilize AI capabilities.