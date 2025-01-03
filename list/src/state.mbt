///| Identifier of a connected editor
pub type ConnectionId UInt64 derive(Eq, Hash)

///| Generates a next unique connection ID
fn next(self : ConnectionId) -> ConnectionId {
  ConnectionId(self._ + 1)
}

///| Error type for editor state operations
pub type! EditorError {
  ///| Error returned when an invalid connection ID is used
  InvalidConnection(ConnectionId)
  ///| Error when trying to modify an already archived document
  AlreadyArchived
}

///| Shows an editor error
pub fn to_string(self : EditorError) -> String {
  match self {
    InvalidConnection(id) => "Invalid connection ID: \{id._}"
    AlreadyArchived => "Document is already archived"
  }
}

///| Email address of a connected editor
pub type EmailAddress String

///| An observable change of the edited document
pub enum Change {
  Added(String)
  Deleted(String)
  Inserted(after~ : String, value~ : String)
} derive(Show)

///| State per connected editor
struct EditorState {
  email : EmailAddress
  mut events : Array[Change]
}

///|
fn EditorState::new(email : EmailAddress) -> EditorState {
  { email, events: [] }
}

///| Document state
pub struct State {
  document : Document
  connected : Map[ConnectionId, EditorState]
  mut last_connection_id : ConnectionId
  mut archived : Bool
  mut email_deadline : @datetime.DateTime
  mut email_recipients : Array[EmailAddress]
}

///| Creates a new empty document editing state
pub fn State::new() -> State {
  let state = {
    document: Document::new(),
    connected: Map::new(),
    last_connection_id: ConnectionId(0),
    archived: false,
    email_deadline: now(),
    email_recipients: [],
  }
  state.update_email_properties()
  state
}

///| Connects a new editor
pub fn connect(
  self : State,
  email : EmailAddress
) -> (ConnectionId, ArrayView[String]) {
  let connection_id = self.last_connection_id.next()
  self.last_connection_id = connection_id
  self.connected.set(connection_id, EditorState::new(email))
  (connection_id, self.document.get())
}

///|
pub fn disconnect(
  self : State,
  connection_id : ConnectionId
) -> Unit!EditorError {
  if self.connected.contains(connection_id) {
    self.connected.remove(connection_id)
  } else {
    raise InvalidConnection(connection_id)
  }
}

///|
pub fn connected_editors(self : State) -> Array[EmailAddress] {
  self.connected
  .iter()
  .map(fn { (_, editor_state) => editor_state.email })
  .to_array()
}

///| Adds a new element to the document as a connected editor
pub fn add(
  self : State,
  connection_id : ConnectionId,
  value : String
) -> Unit!EditorError {
  self.ensure_not_archived!()
  self.ensure_is_connected!(connection_id)
  self.document.add(value)
  self.add_event(Change::Added(value))
  self.update_email_properties()
}

///| Deletes an existing element from the document as a connected editor
pub fn delete(
  self : State,
  connection_id : ConnectionId,
  value : String
) -> Unit!EditorError {
  self.ensure_not_archived!()
  self.ensure_is_connected!(connection_id)
  self.document.delete(value)
  self.add_event(Change::Deleted(value))
  self.update_email_properties()
}

///| Inserts a new element to the document as a connected editor
pub fn insert(
  self : State,
  connection_id : ConnectionId,
  after~ : String,
  value~ : String
) -> Unit!EditorError {
  self.ensure_not_archived!()
  self.ensure_is_connected!(connection_id)
  self.document.insert(after~, value~)
  self.add_event(Change::Inserted(after~, value~))
  self.update_email_properties()
}

///| Returns the list of changes occurred since the last call to poll
pub fn poll(
  self : State,
  connection_id : ConnectionId
) -> Array[Change]!EditorError {
  match self.connected.get(connection_id) {
    Some(editor_state) => {
      let events = editor_state.events
      editor_state.events = []
      events
    }
    None => raise InvalidConnection(connection_id)
  }
}

///| Archives the document
pub fn archive(self : State) -> Unit {
  self.archived = true
  // let name = @archive.DocumentName("TODO")
  // @archive.archive.insert(name, self.document.iter().to_array())
}

///| Returns true if the document is archived
pub fn is_archived(self : State) -> Bool {
  self.archived
}

///| Fails if the document is archived
fn ensure_not_archived(self : State) -> Unit!EditorError {
  guard not(self.archived) else { raise AlreadyArchived }

}

///| Fails if the given `connection_id` is not in the connection map
fn ensure_is_connected(
  self : State,
  connection_id : ConnectionId
) -> Unit!EditorError {
  guard self.connected.contains(connection_id) else {
    raise InvalidConnection(connection_id)
  }

}

///| Queries the WASI wall clock and returns it as a @datetime.DateTime
/// 
/// Note that DateTime has only second precision so we ignore the nanoseconds field
fn now() -> @datetime.DateTime {
  let wasi_now = @wallClock.now()
  @datetime.DateTime::from_unix_mseconds(
    wasi_now.seconds.reinterpret_as_int64(),
  )
}

///| Updates the `email_deadline` and `email_recipients` fields after an update.
fn update_email_properties(self : State) -> Unit {
  let now = now()
  let send_at = now.inc_hour(12)
  let email_list = self.connected_editors()
  self.email_deadline = send_at
  self.email_recipients = email_list
}

///| Adds a change event to each connected editor's state
fn add_event(self : State, change : Change) -> Unit {
  for editor_state in self.connected.values() {
    editor_state.events.push(change)
  }
}

test "connected users can edit" {
  let state = State::new()
  let (cid1, d1) = state.connect(EmailAddress("x@vigoo.dev"))
  state.add!(cid1, "x")
  state.add!(cid1, "y")
  state.disconnect!(cid1)
  let r = state.add?(cid1, "z")
  let (_, d2) = state.connect(EmailAddress("x@vigoo.dev"))
  assert_eq!(d1.length(), 0)
  assert_eq!(r.is_err(), true)
  assert_eq!(d2, ["x", "y"][:])
}

test "poll returns changes" {
  let state = State::new()
  let (cid1, _) = state.connect(EmailAddress("x1@vigoo.dev"))
  let (cid2, _) = state.connect(EmailAddress("x2@vigoo.dev"))
  state.add!(cid1, "x")
  state.add!(cid1, "z")
  let c11 = state.poll!(cid1)
  state.insert!(cid1, after="x", value="y")
  state.delete!(cid1, "x")
  let c12 = state.poll!(cid1)
  let c22 = state.poll!(cid2)
  inspect!(
    c11,
    content=
      #|[Added("x"), Added("z")]
    ,
  )
  inspect!(
    c12,
    content=
      #|[Inserted(after="x", value="y"), Deleted("x")]
    ,
  )
  inspect!(
    c22,
    content=
      #|[Added("x"), Added("z"), Inserted(after="x", value="y"), Deleted("x")]
    ,
  )
}
