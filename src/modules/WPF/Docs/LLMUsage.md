# LLM Usage

## Statement Regarding LLM Usage

Perhaps it's pointless and counter-productive to even say something on the matter, the internet isn't known to be a forgiving place, but I would hate for someone to write off this project just because it contains LLM generated code. I would like for people to understand why I chose this path.

First, I should state that I am not a major proponent of LLM's. While I acknowledge their value, I also recognize the ethical issues training them, using them, and understand that the people who benefit most from them are those who can afford to use them the most. Had I not been introduced to them through my work, it might've been a long time before I considered using them at all. However, as I grew familiar with them at my workplace, their value became undeniably clear. Simply put, LLMs are a force multiplier for people who understand how to effectively use them, and who possess (and manage to retain) their critical thinking skills.

To date, I have only ever paid for Github Copilot and, as of writing, spend $40 a month on it. In the grand scheme, it's a level of investment is so miniscule that it hardly moves the needle. If AI bubble bursts and prices skyrocket, I can say I took advantage of the cheap era and be grateful for what I managed to achieve with it. If the bubble never pops, let's at least try to get something useful out of it.

This project started without LLM assistance in Dec 2025 and that lasted from [1ade6a3](https://github.com/RiverHeart/PowershellStuff/commit/1ade6a3f2314a82d5b00c6780c44cc032225dc14) to [7c7aa15](https://github.com/RiverHeart/PowershellStuff/commit/7c7aa15707a1f8f36cc1d0209bcf7658075b39b3). You can [view the code](https://github.com/RiverHeart/PowershellStuff/tree/7c7aa15707a1f8f36cc1d0209bcf7658075b39b3/src/modules/WPF) at that time if you are interested. I hit a wall trying to refactor the `Grid` keyword and while I could have pushed through it with enough time and effort, work is mentally exhausting and I don't possess the ability to work constantly without burning out. This hurdle would've caused me to stop working on this for a long time, perhaps entirely. I'm sure many people see no value in this project and would have been fine with that outcome but I wasn't.

For me, it's demoralizing to build stuff you feel proud of that no one outside your work will ever benefit from, stuff that will be forgotten and decay away. I've used a lot of open source software, value the open source community, and have wanted to give back in some way. Moreover, this project is something I want for myself, to make something cool that wasn't motivated by a paycheck.

You might say that vibe coding means that I've created nothing, that I'm just a glorified product manager, and, broadly speaking, I don't think you're wrong to think that. With vibe coding, it's hard for outsiders to measure the amount of effort the user put in.

* Did the LLM suggest doing it that way or did the user?
* Did the user review all the LLM generated code?
* Did the user defer entirely to the LLM on the implementation or did they question it, pushback on bad/inefficient suggestions, or brainstorm the best possible solution with it.
* Was the LLM able to complete the feature itself or did it require lots of domain knowledge to steer it in the right direction?
* Did the LLM work perfectly or did it get stuck in a debug loop half way through, requiring the user to intervene and debug the issue themselves?

When I feel like a product manager, I try to remember that the time, energy, and knowledge I spend on this has value, value which affects the outcome in a way that naively writing "create a powershell wpf dsl" can't replicate (at least for now). Not only that, but the scope of what I'm trying to create is so large and complicated that this would be impossible for me otherwise, I would have had to work with someone else to achieve this because I'm not the mythical 10x programmer, I'm a scripter who dabbles in software design. If I have to share credit with the LLM, and all the people whose training data went into it in order to realize this project, then I'm willing to accept that.

In conclusion, while I cannot relay the level of effort I've put into this project know that it feels substantial to me and that I try my best to be thoughtful in how I use the LLM. I do my best to adhere to software best practices and I fancy myself a good at PowerShell and a quality code base does a lot to impact the quality of the LLM generated code. If this project solves a problem for you, I hope that LLM usage is not the primary metric by which you decide whether it's worth using or not.
