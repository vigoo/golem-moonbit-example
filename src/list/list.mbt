///| A document is a list of unique string items
struct Document {
  mut items : Array[String]
}

///| Creates an empty document
pub fn Document::new() -> Document {
  { items: [] }
}

///| Adds a new item to the document
pub fn add(self : Document, item : String) -> Unit {
  if self.items.search(item).is_empty() {
    self.items.push(item)
  }
}

///| Deletes an item from the document
pub fn delete(self : Document, item : String) -> Unit {
  self.items = self.items.filter(fn(i) { item != i })
}

///| Inserts an item to the document after an existing item. If `after` is not in the document, the new item is inserted at the end.
pub fn insert(self : Document, after~ : String, value~ : String) -> Unit {
  let index = self.items.search(after)
  match index {
    Some(index) => self.items.insert(index + 1, value)
    None => self.add(value)
  }
}

///| Gets a view of the document's items
pub fn get(self : Document) -> ArrayView[String] {
  self.items[:]
}

///| Iterates the items in the document
pub fn iter(self : Document) -> Iter[String] {
  self.items.iter()
}

test "new document is empty" {
  let empty = Document::new()
  assert_eq!(empty.items, [])
}

test "basic document operations" {
  let doc = Document::new()
    ..add("x")
    ..add("y")
    ..add("z")
    ..insert(after="y", value="w")
    ..insert(after="a", value="b")
    ..delete("z")
    ..delete("f")
  inspect!(
    doc.get(),
    content=
      #|["x", "y", "w", "b"]
    ,
  )
}
