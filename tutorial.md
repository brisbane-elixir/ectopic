# Ecto 2.0
In this tutorial, we build a simple Phoenix app to demonstrate and play with some of the features of Ecto 2.0.

Ecto 2.0 is about to be released, and brings some major changes and advancements over previous versions.

These include:
- Concurrent transactional tests
- Deprecation of `Ecto.Model`
- Schemaless queries
- `Ecto.multi` for grouping operations within a transaction
- New insert_all, update_all and delete_all functions
- Many to many associations
- Revamped changesets
- Subqueries
- Migrated to DBConnection for performance improvements
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

Lets fire up the app and take a look at what it's generated for us in a browser.
```
iex -S mix phoenix.server
```

## Changesets
Changesets are a key part of ecto - let's review what they're all about, and see to how to use them in the current version of ecto. Later we'll see what is
different in 2.0.
Changesets allow filtering, casting, validation and definition of constraints when manipulating models.
In other words, a changeset is a data structure that controls the changes being sent to the database. Let's see an example:
```
  def changeset(user, params \\ :empty) do
    user
    |> cast(params, ~w(name email), ~w(age))
    |> validate_format(:email, ~r/@/)
    |> validate_inclusion(:age, 18..100)
    |> unique_constraint(:email)
  end
```
Let's play with changesets in our iex console:
```
alias Ectopic.User
changeset = User.changeset(%User{}, %{})
changeset.valid?
changeset.errors
```
And a valid one:
```
changeset = User.changeset(%User{}, %{name: "Fred", email: "fred@skynet.com", bio: "Builds stuff", number_of_pets: 1})
changeset.valid?
changeset.errors
changeset.model
changeset.changes
```
And then let's actually insert this into our DB:
```
alias Ectopic.Repo
Repo.insert(changeset)
```
It's worth noting that you can insert models directly without using changesets:
```
user = %User{name: "jane", email: "jane@skynet.com", bio: "Also builds stuff", number_of_pets: 16}
Repo.insert(user)
```
But this bypasses our opportunity to handle validations and errors in the flexible way changesets gives us.
If you haven't used ecto before, it's worth taking a quick look at it's query DSL:
```
import Ecto.Query
query = from u in User, where: u.email == "fred@skynet.com"
Repo.all(query)
```
If also supports simply piping functions together:
```
User |>
where(email: "fred@skynet.com") |>
Repo.all
```

# Tests
Let's checkout the user test the generator created for us, in `test/models/user_test.exs`
They do some things like:
```
  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end
```
These tests are aimed at being isolated to the functions User model, and don't actually insert any data into the DB.
The generated controller tests, however, test the app from the router to the DB, and do actually insert data:
```
  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @valid_attrs
    assert redirected_to(conn) == user_path(conn, :index)
    assert Repo.get_by(User, @valid_attrs)
  end
```
Each test starts a test transaction which is rolled back at the end of the test. This tests are run sequentially, so
if you have a lot of tests, this would be a prime reason for them taking a long time to run.

Lets run the tests just prove they all run:
```
mix test
```


We'll see what moving to ecto 2.0 means for all the things we have looked at...

# Upgrading to Ecto 2.0
Let's upgrade!
The first step is to update your Phoenix.Ecto dependency to 3.0.0-beta in your mix.exs.
This dependency will effectively depend on Ecto 2.0 and integrate it with Phoenix:
```
{:phoenix_ecto, "~> 3.0.0-beta"}
```
and update our deps:
```
mix deps.get
```
If we run our tests now, we'll see some failures. We have some code changes to do.
First, in `test/test_helper.exs` replace
```
Ecto.Adapters.SQL.begin_test_transaction(Ectopic.Repo)
```
with
```
Ecto.Adapters.SQL.Sandbox.mode(Ectopic.Repo, :manual)
```
In each `test/support/*_case.ex` file replace
```
unless tags[:async] do
  Ecto.Adapters.SQL.restart_test_transaction(Ectopic.Repo, [])
end
```
with
```
:ok = Ecto.Adapters.SQL.Sandbox.checkout(Demo.Repo)
```
Thanks to new `SQL.Sandbox` in ecto 2.0, database tests no longer need to guard against
the `async` tag.
One last thing - one view helper in Phoenix uses a function in Ecto to render error messages which has changed. In `web/views/error_helpers.ex`
replace the two `def translate_error(...) do` functions with just one:
```
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(Ectopic.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(Ectopic.Gettext, "errors", msg, opts)
    end
  end
```
And that's it! Upgrade complete!
Let's run our tests to ensure they pass with `mix test`.

Ok, so there are a few warnings - but those can be easily fixed. It's not possible to tell any speed improvements with
such a small number of tests, it would be interesting to compare on a project with many DB tests.

Let's try some new ecto 2.0 features!

## Schemaless Queries
If you are writing a reporting view, for example, it might be counter production to think how your existing
application schemas relate to the report being generated. It may be simpler to build a query that returns the
data needed, without taking schemas into account.
```
  MyApp.Repo.all(
    from u in "users",
      join: a in "activities",
      on: a.user_id == u.id,
      where: a.start_at > type(^start_at, Ecto.DateTime) and
             a.end_at < type(^end_at, Ecto.DateTime),
      group_by: a.user_id,
      select: %{user_id: a.user_id, interval: a.start_at - a.end_at, count: count(u.id)}
  )
```
Notice the use of `type\2` to give us the same type casting guarantees that a schema give us.

The new `insert_all`, `update_all` and `delete_all` functions further allow us to manipulate
our data without needing a schema in between at all:
```
# Insert data into posts and return its ID
[%{id: id}] =
  MyApp.Repo.insert_all "posts", [[title: "hello"]], returning: [:id]

# Use the ID to trigger updates
post = from p in "posts", where: p.id == ^id
{1, _} = MyApp.Repo.update_all post, set: [title: "new title"]

# As well as for deletes
{1, _} = MyApp.Repo.delete_all post
```

## `Ecto.Model` Deprecated
changeset.model has been renamed to changeset.data (we no longer have "models" in Ecto)

Models were 'removed' in ecto 1.1 - why is this? It's really just a naming concern to make it more clear
what they really are. In OO languages, you would say a model can be instantiated and it would have methods
that contain business logic. However, the data that comes from the database in Ecto is just data. It is an Elixir
struct. It is not an Ecto model.

A model, a controller or a view (from the MVC pattern) are just group of functions that share similar responsibilities.
They are just guidelines on how to group code towards a common purpose. Basically, Ecto.Model has been renamed to Ecto.Schema
and some functions moved around.

## Schemas without the Database
Ecto schemas are used to map any data source into an Elixir struct. It is a common misconception to think Ecto schemas map only to your database tables.

For instance, when you write a web application using Phoenix and you use Ecto to receive external changes and apply such changes to your database, we are actually mapping the schema to two different sources:
```
Database <-> Ecto schema <-> Forms / API
```
We can however, use schemas without the database. For example, we want to validate data coming in via an API and
use structs for better type guarantees. We can use a schema like this:
```
defmodule Registration do
  use Ecto.Schema

  embedded_schema do
    field :first_name
    field :last_name
    field :email
  end
end

fields = [:first_name, :last_name, :email]

changeset =
  %Registration{}
  |> Ecto.Changeset.cast(params["sign_up"], fields)
  |> validate_required(...)
  |> validate_length(...)


if changeset.valid? do
  # Get the modified registration struct out of the changeset
  registration = Ecto.Changeset.apply_changes(changeset)
  ...
else
  ...
end
```

## Revamped Changesets
Passing required and optional fields to `cast/4` is deprecated in favor of `cast/3` and `validate_required/3`. We can update our
User model like this:
```
  @required_fields ~w(name email bio number_of_pets)a
  @optional_fields ~w()a

  @doc """
  ...
  """
  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
```
Note the `a` at the end of the `~w` lists - this converts all items to atoms.

## Subqueries
Ecto v2.0 introduces Ecto.Query.subquery/1 that will convert any query into a subquery to be used either as part of a from or a join.
If we wanted the average number of pets, we could write:
```
query = from u in User, select: avg(u.number_of_pets)
Repo.all query
```
However, if we need the average of the most recent x users, we need subqueries:
```
subquery = from u in User, select: [:number_of_pets], order_by: [desc: :inserted_at], limit: 5
query = from p in subquery(subquery), select: avg(p.number_of_pets)
Repo.all query
```
From here, let's play with the following new features listed in the changelog:
## Concurrent transactional tests
## Insert all
## Many to many
## Improved association support

# Resources
https://github.com/elixir-lang/ecto/blob/v2.0.0-beta.0/CHANGELOG.md

http://blog.plataformatec.com.br/2016/05/ectos-insert_all-and-schemaless-queries/

http://blog.plataformatec.com.br/2016/02/ecto-2-0-0-beta-0-is-out/

http://blog.plataformatec.com.br/2015/12/ecto-v1-1-released-and-ecto-v2-0-plans/

http://pages.plataformatec.com.br/ebook-whats-new-in-ecto-2-0

https://github.com/elixir-lang/ecto/issues/1114

http://www.phoenixframework.org/docs/ecto-models
