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
And let ecto create the DB for our app:
```
mix ecto.create
```
Depending on the state of your local postgres, this might fail for several reasons.
These are documented here: http://www.phoenixframework.org/docs/mix-tasks,
although I found them a little misleading as they assume you can already login
to psql, and if it's a new installation you may not have a user at all.
The answer is to create a user from the cmd line rather than the psql terminal.

If you've just installed postgres, it's likely you need to create the 'postgres' user:
```
createuser --login --createdb postgres
```
Now, our `mix ecto.create` should succeed.
Next, let's create an Ecto model. We're actually not using Ecto 2.0 yet.
Since it's not released, Phoenix still uses 1.x by default. We'll create some models
using the older version, and then upgrade to show what has changed between versions.
```
mix phoenix.gen.html User users name:string email:string bio:string number_of_pets:integer
```
Here, we're using a phoenix generator to create not only a model, but a controller and HTML view as well.
Note, the generators also support creating JSON views instead. Using these is a nice way to learn how things
are structured in Phoenix, but once you get a handle on that, they're rarely useful for production apps.

As it suggests, we'll add the 'users' route to `web/router.ex`:
```
resources "/users", UserController
```
And then run the generated database migration:
```
mix ecto.migrate
```
Just for completeness, let's take a look at what it created in postgres:
```
psql -U postgres
postgres=> \connect ectopic_dev
You are now connected to database "ectopic_dev" as user "postgres".
ectopic_dev=> \d
                List of relations
 Schema |       Name        |   Type   |  Owner
--------+-------------------+----------+----------
 public | schema_migrations | table    | postgres
 public | users             | table    | postgres
 public | users_id_seq      | sequence | postgres
(3 rows)

ectopic_dev=> \d users
                                       Table "public.users"
     Column     |            Type             |                     Modifiers
----------------+-----------------------------+----------------------------------------------------
 id             | integer                     | not null default nextval('users_id_seq'::regclass)
 name           | character varying(255)      |
 email          | character varying(255)      |
 bio            | character varying(255)      |
 number_of_pets | integer                     |
 inserted_at    | timestamp without time zone | not null
 updated_at     | timestamp without time zone | not null
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
```
Also take a look at `web/models/user.ex` and `priv/repo/migrations/20160426054138_create_user.exs` to see the model and migration generated.

## Changesets
Changesets are a key part of ecto - let's review what they're all about, and see to how to use them in the current version of ecto. Later we'll see what is
different in 2.0.
