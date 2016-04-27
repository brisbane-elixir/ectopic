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
  Ecto.Adapters.SQL.restart_test_transaction(Demo.Repo, [])
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

Ok, so there are a few warnings - but those can be easily fixed.

# Resources
http://blog.plataformatec.com.br/2016/02/ecto-2-0-0-beta-0-is-out/
http://blog.plataformatec.com.br/2015/12/ecto-v1-1-released-and-ecto-v2-0-plans/
http://www.phoenixframework.org/docs/ecto-models
