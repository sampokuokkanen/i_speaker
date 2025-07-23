---
theme: default
title: "Building AI-Powered Ruby Applications"
titleTemplate: '%s'
layout: cover
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
download: true
mdc: true
talkDurationMinutes: 25
progressBarStartSlide: 2
---

# Building AI-Powered Ruby Applications

Learn how to integrate AI capabilities into your Ruby applications using local models

<div class="absolute bottom-10 left-10">
  <small>Duration: 25 minutes | Audience: Ruby developers</small>
</div>

<!--
Explain introduction to ai in ruby applications with practical examples and encourage audience questions.
-->

---

# Setting up Ollama for Local AI

- To set up Ollama for local AI, create a new Ruby project and add the following dependencies to your Gemfile: `ollama` and `activesupport`.
- Next, initialize the Ollama library in your main application file (e.g., app.rb) by calling `Ollama.init()` before booting up your Ruby application.
- Configure the Ollama model by creating a new class that inherits from `Ollama::Model` and defines the AI capabilities you want to use, such as classification or regression.
- Use the `ollama` gem's built-in APIs, such as `model.predict()` or `dataset.load()`, to interact with your local Ollama instance within your Ruby application.

<!--
Explain setting up ollama for local ai with practical examples and encourage audience questions.
-->

---

# Creating Simple Chat Interfaces

- Use Ruby's built-in `require` method to include the necessary libraries for creating chat interfaces, such as Twilio or Nexmo APIs.
- Utilize the `Thread` class in Ruby to handle asynchronous communication between clients and servers.
- Implement a basic socket server using Ruby's built-in `socket` library to establish real-time connections with clients.
- Leverage the `actionpack` framework's built-in support for WebSockets to enable bi-directional communication over HTTP/2.

<!--
Explain creating simple chat interfaces with practical examples and encourage audience questions.
-->

---

# Building AI-Powered Tools

- Use frameworks like Ruby-GNUTS or Rake to automate tasks and integrate AI-powered tools into your workflow.
- Leverage libraries such as OpenCV and Computer Vision gems in Ruby to build image recognition models for computer vision tasks.
- Apply machine learning techniques using Scikit-learn and TensorFlow gems to train predictive models that can be integrated into your applications.
- Integrate with cloud services like AWS SageMaker or Google Cloud AI Platform to access pre-built AI frameworks and tools.

<!--
Explain building ai-powered tools with practical examples and encourage audience questions.
-->

---

# Best Practices and Security Considerations

- Always use secure libraries like OpenSSL for encryption and hashing
- Validate and sanitize user input thoroughly to prevent SQL injection and cross-site scripting (XSS) attacks
- Implement proper authentication and authorization mechanisms using Ruby's built-in authlogic gem or other reputable alternatives
- Regularly update dependencies, including Ruby itself, to ensure you have the latest security patches

<!--
Explain best practices and security considerations with practical examples and encourage audience questions.
-->

---
layout: center
class: text-center
---

# Thank You!

Questions?

<!--
Thank you for your attention. I'm happy to answer any questions you may have.
-->
