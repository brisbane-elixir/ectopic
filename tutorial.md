# Ecto 2.0
In this tutorial, we build a simple Phoenix app to demonstrate and play with some of the features of Ecto 2.0.

Ecto 2.0 is about to be released, and brings some major changes and advancements over previous versions.

These include:
- Concurrent transactional tests
- Many to many associations
- Ecto Models are being removed
- Revamped changesets
- Subqueries
- And more!

Let's start exploring!

First, we'll create a new phoenix app. We'll assume you already have elixir installed, if not, follow the installation instructions online.

Let's update our phoenix mix archive, so we're using the latest version.
```
mix archive.install https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez
```
I'm gonna call my ecto app 'ectopic'. Let's create it:
```
mix phoenix.new ectopic
cd ectopic
```
