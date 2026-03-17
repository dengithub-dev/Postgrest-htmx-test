create or replace function apis.sanitize_html(text) returns text as $$
  select replace(replace(replace(replace(replace($1, '&', '&amp;'), '"', '&quot;'),'>', '&gt;'),'<', '&lt;'), '''', '&apos;')
$$ language sql;

create or replace function apis.html_todo(apis.todos) returns text as $$
  select format($html$
    <div>
      <%2$s>
        %3$s
      </%2$s>
    </div>
    $html$,
    $1.id,
    case when $1.done then 's' else 'span' end,
    apis.sanitize_html($1.task)
  );
$$ language sql stable;

create or replace function apis.html_all_todos() returns text as $$
  select coalesce(
    string_agg(apis.html_todo(t), '<hr/>' order by t.id),
    '<p><em>There is nothing else to do.</em></p>'
  )
  from apis.todos t;
$$ language sql;
--

create or replace function apis.add_todo(_task text) returns "text/html" as $$
  insert into apis.todos(task) values (_task);
  select apis.html_all_todos();
$$ language sql;

create or replace function apis.index() returns "text/html" as $$
  select $html$
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>PostgREST + HTMX To-Do List</title>
      <!-- Pico CSS for CSS styling -->
      <link href="https://cdn.jsdelivr.net/npm/@picocss/pico@next/css/pico.min.css" rel="stylesheet"/>
      <!-- htmx for AJAX requests -->
      <script src="https://unpkg.com/htmx.org"></script>
    </head>
    <body>
      <main class="container"
            style="max-width: 600px"
            hx-headers='{"Accept": "text/html"}'>
        <article>
          <h5 style="text-align: center;">
            PostgREST + HTMX To-Do List
          </h5>
          <form hx-post="/rpc/add_todo"
                hx-target="#todo-list-area"
                hx-trigger="submit"
                hx-on="htmx:afterRequest: this.reset()">
            <input type="text" name="_task" placeholder="Add a todo...">
          </form>
          <div id="todo-list-area">
            $html$
              || apis.html_all_todos() ||
            $html$
          <div>
        </article>
      </main>
      <!-- Script for Ionicons icons -->
      <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
      <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>
    </body>
    </html>
  $html$;
$$ language sql;
--

create or replace function apis.html_todo(apis.todos) returns text as $$
  select format($html$
    <div class="grid">
      <div id="todo-edit-area-%1$s">
        <form id="edit-task-state-%1$s"
              hx-post="/rpc/change_todo_state"
              hx-vals='{"_id": %1$s, "_done": %4$s}'
              hx-target="#todo-list-area"
              hx-trigger="click">
          <%2$s style="cursor: pointer">
            %3$s
          </%2$s>
        </form>
      </div>
      <div style="text-align: right">
        <button class="outline"
                hx-get="/rpc/html_editable_task"
                hx-vals='{"_id": "%1$s"}'
                hx-target="#todo-edit-area-%1$s"
                hx-trigger="click">
          <span>
            <ion-icon name="create"></ion-icon>
          </span>
        </button>
        <button class="outline contrast"
                hx-post="/rpc/delete_todo"
                hx-vals='{"_id": %1$s}'
                hx-target="#todo-list-area"
                hx-trigger="click">
          <span>
            <ion-icon name="trash" style="color: #f87171"></ion-icon>
          </span>
        </button>
      </div>
    </div>
    $html$,
    $1.id,
    case when $1.done then 's' else 'span' end,
    apis.sanitize_html($1.task),
    (not $1.done)::text
  );
$$ language sql stable;

--
create or replace function apis.html_editable_task(_id int) returns "text/html" as $$
  select format ($html$
  <form id="edit-task-%1$s"
        hx-post="/rpc/change_todo_task"
        hx-headers='{"Accept": "text/html"}'
        hx-vals='{"_id": %1$s}'
        hx-target="#todo-list-area"
        hx-trigger="submit,focusout">
    <input id="task-%1$s" type="text" name="_task" value="%2$s" autofocus>
  </form>
  $html$,
    id,
    apis.sanitize_html(task)
  )
  from apis.todos
  where id = _id;
$$ language sql;

--

create or replace function apis.change_todo_state(id int, _done boolean) returns "text/html" as $$
  update apis.todos set done = _done where id = id;
  select apis.html_all_todos();
$$ language sql;

create or replace function apis.change_todo_task(id int, _task text) returns "text/html" as $$
  update apis.todos set task = _task where id = id;
  select apis.html_all_todos();
$$ language sql;

create or replace function apis.delete_todo(id int) returns "text/html" as $$
  delete from apis.todos where id = id;
  select apis.html_all_todos();
$$ language sql;
